-- Interrupt questing for merchant maintenance and then resume the same quest step.
local Gear=require("gear")
local M={}
function M.sellable(item,policy)
    local info=item.info
    if not info or not item.id or policy.protected[item.id] then return false end
    if info.class_id==12 or info.item_type=="Quest" or info.is_crafting_reagent then return false end
    return info.quality==0 and (info.sell_price or 0)>0
end
function M.new(api,options)
    local policy={protected=(options and options.protected) or {},repair_threshold=0.2,
        reserve_slots=2,target_free_slots=6,auto_equip=true,auto_repair=true,auto_sell=true}
    for k,v in pairs(options or {}) do policy[k]=v end
    local self={api=api,policy=policy,state="idle",generation=0,next_scan=0,next_input=0,equip_backoff={},vendor_failures={}}
    local function vendor_key(v)
        if not v then return "unknown" end
        if v.key then return tostring(v.key) end
        if v.npc_id then return tostring(v.npc_id) end
        local p=v.position or {};return table.concat({tostring(p.x or ""),tostring(p.y or ""),tostring(p.z or "")},":")
    end
    function self:defer_service(reason,delay,reject_vendor)
        local now=self.api.time()
        if reject_vendor and self.vendor then self.vendor_failures[vendor_key(self.vendor)]=now+math.max(300,delay or 60) end
        if self.api.log then self.api.log("service_deferred",{reason=reason,retry_in=delay or 60,vendor=self.vendor and self.vendor.npc_id}) end
        if self.api.close_merchant then self.api.close_merchant() end
        self.generation=self.generation+1;self.state="idle";self.vendor=nil;self.sell_needed=nil;self.deadline=nil
        self.api.stop();self.next_scan=now+(delay or 60)
        return "service_deferred:"..tostring(reason)
    end
    function self:defer_equip()
        if self.pending then
            local key=self.pending.item.link
            local row=self.equip_backoff[key] or {failures=0}
            row.failures=row.failures+1;row.until_time=self.api.time()+math.min(600,30*2^(row.failures-1))
            self.equip_backoff[key]=row
        end
    end
    function self:cancel()
        if self.pending then self:defer_equip();self.api.clear_equip(self.pending.slot) end
        self.generation=self.generation+1;self.state="idle";self.vendor=nil;self.pending=nil
        self.api.stop()
    end
    function self:tick(equipment_only)
        local a=self.api;local now=a.time()
        if self.state=="equipping" then
            local equipped=a.equipped_link(self.pending.slot)
            local wanted=self.pending.item.link
            local same=equipped==wanted
            -- Require the bag instance to disappear before accepting a changed display link.
            if not same and type(equipped)=="string" and type(wanted)=="string" then
                local id=equipped:match("item:(%d+):")
                same=id~=nil and id==wanted:match("item:(%d+):")
                    and equipped~=self.pending.previous_link
                    and a.bag_link(self.pending.item.bag,self.pending.item.slot)~=wanted
            end
            if same then
                if a.log then a.log("equip_confirmed",{slot=self.pending.slot,item=self.pending.item.link}) end
                self.pending=nil;self.state="idle";self.next_scan=now+2;return "equipped_upgrade" end
            if now>self.deadline then
                if a.log then a.log("equip_not_confirmed",{slot=self.pending.slot,item=self.pending.item.link}) end
                self:defer_equip();a.clear_equip(self.pending.slot);self.state="idle";self.pending=nil;self.next_scan=now+10;return "equip_not_confirmed" end
            if a.pending_equip_slot()==self.pending.slot and now>=self.next_input then
                self.next_input=now+1;a.confirm_equip(self.pending.slot)
            end
            return "equipping_upgrade"
        end
        if equipment_only and self.state~="idle" then return nil end
        if self.state~="idle" then
            if now>self.deadline then return self:defer_service("vendor_timeout",30,true) end
            if self.state=="travel" then return "vendor_travel" end
            if self.state=="failed" then return self:defer_service("vendor_navigation_failed",30,true) end
            if not a.merchant_open() then
                if now>=self.next_input then self.next_input=now+1;a.interact_vendor(self.vendor) end
                return "opening_vendor"
            end
            local snapshot=a.inventory()
            if policy.auto_repair and snapshot.durability<policy.repair_threshold then
                if not a.can_repair() then return self:defer_service("vendor_cannot_repair",300,true) end
                local cost=a.repair_cost()
                if cost>snapshot.money then
                    -- Selling verified junk may fund a repair even when the
                    -- bags are not full. Re-read money on the next tick.
                    if policy.auto_sell then
                        for _,item in ipairs(snapshot.items) do
                            if M.sellable(item,policy) and a.bag_link(item.bag,item.slot)==item.link then
                                if now>=self.next_input then self.next_input=now+0.5;a.sell(item.bag,item.slot) end
                                return "selling_junk_for_repair"
                            end
                        end
                    end
                    return self:defer_service("insufficient_repair_money",120,false)
                end
                if now>=self.next_input then self.next_input=now+1;a.repair() end
                return "repairing"
            end
            if snapshot.free_slots<policy.target_free_slots and self.sell_needed then
                for _,item in ipairs(snapshot.items) do
                    if M.sellable(item,policy) then
                        if now>=self.next_input then
                            -- Verify the exact instance again before mutating its bag slot.
                            if a.bag_link(item.bag,item.slot)==item.link then a.sell(item.bag,item.slot) end
                            self.next_input=now+0.5
                        end
                        return "selling_junk"
                    end
                end
                if snapshot.free_slots<=policy.reserve_slots then return self:defer_service("no_sellable_junk",120,false) end
            end
            a.close_merchant();self:cancel();self.next_scan=now+3;return "vendor_finished"
        end
        if now<self.next_scan then return nil end
        self.next_scan=now+2
        local snapshot=a.inventory()
        if policy.auto_equip then
            local candidates={}
            for _,item in ipairs(snapshot.items) do
                local blocked=self.equip_backoff[item.link]
                if not blocked or now>=blocked.until_time then candidates[#candidates+1]=item end
            end
            local upgrade=Gear.choose(candidates,snapshot.worn,snapshot.character)
            if upgrade and a.bag_link(upgrade.item.bag,upgrade.item.slot)==upgrade.item.link then
                upgrade.previous_link=a.equipped_link(upgrade.slot);self.pending=upgrade;self.state="equipping";self.deadline=now+8;self.next_input=now+1
                -- false can mean the client opened a bind-on-equip prompt; the
                -- pending slot is latched on a later frame. Keep the request
                -- alive and confirm or time it out from the equipping state.
                a.equip(upgrade.item.bag,upgrade.item.slot,upgrade.slot)
                return "equipping_upgrade"
            end
        end
        if equipment_only then return nil end
        local repair=policy.auto_repair and snapshot.durability<policy.repair_threshold
        local sell=policy.auto_sell and snapshot.free_slots<=policy.reserve_slots
        if not repair and not sell then return nil end
        if a.merchant_open() then
            self.sell_needed=sell;self.state="interact";self.deadline=now+60
            return self:tick(false)
        end
        for key,expires in pairs(self.vendor_failures) do if now>=expires then self.vendor_failures[key]=nil end end
        local vendor=a.choose_vendor(repair,self.vendor_failures)
        if not vendor then
            if a.log then a.log("service_vendor_unavailable",{repair=repair,sell=sell,retry_in=60}) end
            self.next_scan=now+60;return "service_deferred:vendor_route_required"
        end
        self.vendor=vendor;self.sell_needed=sell;self.state="travel"
        -- A learned vendor can be anywhere on the current map. Give Sentinel
        -- enough time for a real zone-scale route while keeping a hard cap.
        self.deadline=now+math.max(180,math.min(1200,120+(vendor.distance or 0)/3))
        self.generation=self.generation+1;local generation=self.generation
        a.move(vendor.position,function(ok)
            if generation~=self.generation then return end
            self.state=ok and "interact" or "failed"
        end)
        return "vendor_travel"
    end
    return self
end
return M
