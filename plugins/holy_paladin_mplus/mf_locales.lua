-- UTF-8 display catalogs. Columns: English, German, French, Spanish, Italian,
-- Portuguese, Russian, Korean, Simplified Chinese, Traditional Chinese, Japanese.
-- Region variants share a catalog; protocol identifiers are never translated.
local locales={'enUS','deDE','frFR','esES','itIT','ptBR','ruRU','koKR','zhCN','zhTW','jaJP'}
local data=[[
COMMAND|BEFEHLE|COMMANDES|MANDOS|COMANDI|COMANDOS|КОМАНДЫ|명령|指令|指令|コマンド
COMBAT|KAMPF|COMBAT|COMBATE|COMBATTIMENTO|COMBATE|БОЙ|전투|战斗|戰鬥|戦闘
ROUTE|ROUTE|ITINÉRAIRE|RUTA|PERCORSO|ROTA|МАРШРУТ|경로|路线|路線|ルート
SAFETY|SICHERHEIT|SÉCURITÉ|SEGURIDAD|SICUREZZA|SEGURANÇA|БЕЗОПАСНОСТЬ|안전|安全|安全|安全
LOGS|PROTOKOLLE|JOURNAUX|REGISTROS|REGISTRI|REGISTROS|ЖУРНАЛЫ|로그|日志|日誌|ログ
METRICS|MESSWERTE|MESURES|MÉTRICAS|METRICHE|MÉTRICAS|МЕТРИКИ|측정값|指标|指標|メトリクス
SETUP|EINRICHTUNG|CONFIGURATION|CONFIGURACIÓN|CONFIGURAZIONE|CONFIGURAÇÃO|НАСТРОЙКА|설정|设置|設定|設定
COMMAND CENTER|BEFEHLSZENTRALE|CENTRE DE COMMANDE|CENTRO DE MANDO|CENTRO DI COMANDO|CENTRO DE COMANDO|ЦЕНТР УПРАВЛЕНИЯ|명령 센터|指挥中心|指揮中心|コマンドセンター
COMBAT LOADOUT|KAMPFAUSSTATTUNG|ÉQUIPEMENT DE COMBAT|CONFIGURACIÓN DE COMBATE|ASSETTO DI COMBATTIMENTO|CONFIGURAÇÃO DE COMBATE|БОЕВЫЕ НАСТРОЙКИ|전투 설정|战斗配置|戰鬥配置|戦闘設定
ROUTE CONTROL|ROUTENSTEUERUNG|CONTRÔLE DU PARCOURS|CONTROL DE RUTA|CONTROLLO PERCORSO|CONTROLE DE ROTA|УПРАВЛЕНИЕ МАРШРУТОМ|경로 제어|路线控制|路線控制|ルート制御
SAFETY & RECOVERY|SICHERHEIT & WIEDERHERSTELLUNG|SÉCURITÉ ET REPRISE|SEGURIDAD Y RECUPERACIÓN|SICUREZZA E RIPRISTINO|SEGURANÇA E RECUPERAÇÃO|БЕЗОПАСНОСТЬ И ВОССТАНОВЛЕНИЕ|안전 및 복구|安全与恢复|安全與恢復|安全と復旧
DIAGNOSTICS|DIAGNOSE|DIAGNOSTIC|DIAGNÓSTICO|DIAGNOSTICA|DIAGNÓSTICO|ДИАГНОСТИКА|진단|诊断|診斷|診断
PERFORMANCE|LEISTUNG|PERFORMANCES|RENDIMIENTO|PRESTAZIONI|DESEMPENHO|ПРОИЗВОДИТЕЛЬНОСТЬ|성능|性能|效能|パフォーマンス
SETUP & HELP|EINRICHTUNG & HILFE|CONFIGURATION ET AIDE|CONFIGURACIÓN Y AYUDA|CONFIGURAZIONE E AIUTO|CONFIGURAÇÃO E AJUDA|НАСТРОЙКА И СПРАВКА|설정 및 도움말|设置与帮助|設定與說明|設定とヘルプ
NAVIGATION MODULES|NAVIGATIONSMODULE|MODULES DE NAVIGATION|MÓDULOS DE NAVEGACIÓN|MODULI DI NAVIGAZIONE|MÓDULOS DE NAVEGAÇÃO|МОДУЛИ НАВИГАЦИИ|탐색 모듈|导航模块|導航模組|ナビゲーション
FOREVER PATHFINDING COMMAND|FOREVER-NAVIGATIONSSTEUERUNG|NAVIGATION FOREVER|NAVEGACIÓN FOREVER|NAVIGAZIONE FOREVER|NAVEGAÇÃO FOREVER|НАВИГАЦИЯ FOREVER|FOREVER 경로 제어|FOREVER 寻路控制|FOREVER 尋路控制|FOREVER 経路制御
LOCAL LINK|LOKALE VERBINDUNG|LIAISON LOCALE|ENLACE LOCAL|COLLEGAMENTO LOCALE|CONEXÃO LOCAL|ЛОКАЛЬНАЯ СВЯЗЬ|로컬 연결|本地连接|本機連線|ローカル接続
LOCAL NAVIGATION LINK|LOKALE NAVIGATIONSVERBINDUNG|LIAISON DE NAVIGATION LOCALE|ENLACE DE NAVEGACIÓN LOCAL|COLLEGAMENTO DI NAVIGAZIONE LOCALE|CONEXÃO DE NAVEGAÇÃO LOCAL|ЛОКАЛЬНАЯ НАВИГАЦИЯ|로컬 탐색 연결|本地导航连接|本機導航連線|ローカルナビゲーション
BATTLEGROUND PLAYER|SCHLACHTFELDSPIELER|JOUEUR DE CHAMP DE BATAILLE|JUGADOR DE CAMPO DE BATALLA|GIOCATORE CAMPO DI BATTAGLIA|JOGADOR DE CAMPO DE BATALHA|БОЕЦ ПОЛЯ БОЯ|전장 플레이어|战场玩家|戰場玩家|戦場プレイヤー
1-90 LEVELING|STUFENAUFSTIEG 1–90|PROGRESSION 1–90|SUBIDA DE NIVEL 1–90|LIVELLAMENTO 1–90|EVOLUÇÃO 1–90|ПРОКАЧКА 1–90|1–90 레벨업|1–90 级升级|1–90 級升級|レベル上げ 1–90
BG + LEVELER READY|SCHLACHTFELD + LEVELER BEREIT|CHAMP DE BATAILLE + PROGRESSION PRÊTS|CAMPO DE BATALLA + SUBIDA LISTOS|CAMPO DI BATTAGLIA + LIVELLI PRONTI|CAMPO DE BATALHA + EVOLUÇÃO PRONTOS|ПОЛЕ БОЯ И ПРОКАЧКА ГОТОВЫ|전장 및 레벨업 준비|战场与升级就绪|戰場與升級就緒|戦場・レベル上げ準備完了
OPEN MODULE|MODUL ÖFFNEN|OUVRIR LE MODULE|ABRIR MÓDULO|APRI MODULO|ABRIR MÓDULO|ОТКРЫТЬ МОДУЛЬ|모듈 열기|打开模块|開啟模組|モジュールを開く
LIVE CHARACTER DETECTION|LIVE-CHARAKTERERKENNUNG|DÉTECTION DU PERSONNAGE|DETECCIÓN DEL PERSONAJE|RILEVAMENTO PERSONAGGIO|DETECÇÃO DO PERSONAGEM|ОПРЕДЕЛЕНИЕ ПЕРСОНАЖА|실시간 캐릭터 감지|实时角色检测|即時角色偵測|キャラクター検出
CHARACTER|CHARAKTER|PERSONNAGE|PERSONAJE|PERSONAGGIO|PERSONAGEM|ПЕРСОНАЖ|캐릭터|角色|角色|キャラクター
SPECIALIZATION|SPEZIALISIERUNG|SPÉCIALISATION|ESPECIALIZACIÓN|SPECIALIZZAZIONE|ESPECIALIZAÇÃO|СПЕЦИАЛИЗАЦИЯ|전문화|专精|專精|専門分野
ACTIVE COMBAT PLUGIN|AKTIVES KAMPF-PLUGIN|PLUGIN DE COMBAT ACTIF|PLUGIN DE COMBATE ACTIVO|PLUGIN DI COMBATTIMENTO ATTIVO|PLUGIN DE COMBATE ATIVO|АКТИВНЫЙ БОЕВОЙ ПЛАГИН|활성 전투 플러그인|当前战斗插件|目前戰鬥外掛|使用中の戦闘プラグイン
LIVE HOTKEYS|AKTUELLE TASTENKÜRZEL|RACCOURCIS ACTIFS|ATAJOS ACTIVOS|SCORCIATOIE ATTIVE|ATALHOS ATIVOS|ГОРЯЧИЕ КЛАВИШИ|실시간 단축키|当前快捷键|目前快捷鍵|ホットキー
CHANGE HOTKEY|TASTENKÜRZEL ÄNDERN|MODIFIER LE RACCOURCI|CAMBIAR ATAJO|CAMBIA SCORCIATOIA|ALTERAR ATALHO|ИЗМЕНИТЬ КЛАВИШУ|단축키 변경|更改快捷键|變更快捷鍵|キーを変更
LIVE ROUTE|AKTUELLE ROUTE|PARCOURS ACTUEL|RUTA ACTUAL|PERCORSO ATTUALE|ROTA ATUAL|ТЕКУЩИЙ МАРШРУТ|실시간 경로|当前路线|目前路線|現在のルート
OWNER|BESITZER|PROPRIÉTAIRE|PROPIETARIO|PROPRIETARIO|RESPONSÁVEL|ВЛАДЕЛЕЦ|소유자|控制方|控制方|制御元
PHASE|PHASE|PHASE|FASE|FASE|FASE|ФАЗА|단계|阶段|階段|段階
READINESS|BEREITSCHAFT|DISPONIBILITÉ|DISPONIBILIDAD|DISPONIBILITÀ|PRONTIDÃO|ГОТОВНОСТЬ|준비 상태|就绪状态|就緒狀態|準備状況
ROUTE COMMANDS|ROUTENBEFEHLE|COMMANDES DU PARCOURS|COMANDOS DE RUTA|COMANDI PERCORSO|COMANDOS DE ROTA|КОМАНДЫ МАРШРУТА|경로 명령|路线指令|路線指令|ルートコマンド
PAUSE|PAUSE|PAUSE|PAUSAR|PAUSA|PAUSAR|ПАУЗА|일시 정지|暂停|暫停|一時停止
RESUME|FORTSETZEN|REPRENDRE|REANUDAR|RIPRENDI|RETOMAR|ПРОДОЛЖИТЬ|재개|继续|繼續|再開
REPLAN|NEU PLANEN|RECALCULER|RECALCULAR|RICALCOLA|RECALCULAR|ПЕРЕСТРОИТЬ|재계획|重新规划|重新規劃|再計画
CHECK LOCAL CONNECTION|LOKALE VERBINDUNG PRÜFEN|VÉRIFIER LA LIAISON LOCALE|COMPROBAR CONEXIÓN LOCAL|VERIFICA CONNESSIONE LOCALE|VERIFICAR CONEXÃO LOCAL|ПРОВЕРИТЬ ЛОКАЛЬНУЮ СВЯЗЬ|로컬 연결 확인|检查本地连接|檢查本機連線|ローカル接続を確認
RECOVERY OPTIONS|WIEDERHERSTELLUNGSOPTIONEN|OPTIONS DE REPRISE|OPCIONES DE RECUPERACIÓN|OPZIONI DI RIPRISTINO|OPÇÕES DE RECUPERAÇÃO|ПАРАМЕТРЫ ВОССТАНОВЛЕНИЯ|복구 옵션|恢复选项|恢復選項|復旧設定
WORLD ROUTE OVERLAY|ROUTENANZEIGE IN DER WELT|PARCOURS DANS LE MONDE|RUTA SOBRE EL MUNDO|PERCORSO NEL MONDO|ROTA NO MUNDO|МАРШРУТ В МИРЕ|월드 경로 표시|世界路线叠加|世界路線疊加|ワールド内の経路表示
STALL WATCHDOG|STILLSTANDSÜBERWACHUNG|DÉTECTION DE BLOCAGE|DETECTOR DE BLOQUEOS|RILEVAMENTO BLOCCHI|DETECTOR DE TRAVAMENTO|КОНТРОЛЬ ЗАСТРЕВАНИЯ|정체 감시|停滞监测|停滯監測|停止監視
SECONDS|SEKUNDEN|SECONDES|SEGUNDOS|SECONDI|SEGUNDOS|СЕКУНД|초|秒|秒|秒
MAXIMUM REPLANS|MAXIMALE NEUPLANUNGEN|RECALCULS MAXIMAUX|RECÁLCULOS MÁXIMOS|RICALCOLI MASSIMI|RECÁLCULOS MÁXIMOS|ЛИМИТ ПЕРЕСТРОЕНИЙ|최대 재계획|最大重新规划次数|最大重新規劃次數|再計画上限
REMEMBER TROUBLE SPOTS|PROBLEMSTELLEN MERKEN|MÉMORISER LES ZONES À RISQUE|RECORDAR ZONAS PROBLEMÁTICAS|RICORDA ZONE PROBLEMATICHE|LEMBRAR ÁREAS PROBLEMÁTICAS|ЗАПОМИНАТЬ ПРОБЛЕМНЫЕ МЕСТА|문제 지점 기억|记住问题地点|記住問題地點|問題地点を記憶
BACKGROUND ARTWORK|HINTERGRUNDBILD|ILLUSTRATION DE FOND|ILUSTRACIÓN DE FONDO|ILLUSTRAZIONE DI SFONDO|ARTE DE FUNDO|ФОНОВОЕ ИЗОБРАЖЕНИЕ|배경 그림|背景插画|背景插畫|背景アート
RECOVERY & SUPPORT REPORT|WIEDERHERSTELLUNGSBERICHT|RAPPORT DE REPRISE ET D'ASSISTANCE|INFORME DE RECUPERACIÓN Y SOPORTE|RAPPORTO DI RIPRISTINO E ASSISTENZA|RELATÓRIO DE RECUPERAÇÃO E SUPORTE|ОТЧЁТ ДЛЯ ПОДДЕРЖКИ|복구 및 지원 보고서|恢复与支持报告|恢復與支援報告|復旧・サポートレポート
CLEAR HISTORY|VERLAUF LÖSCHEN|EFFACER L'HISTORIQUE|BORRAR HISTORIAL|CANCELLA CRONOLOGIA|LIMPAR HISTÓRICO|ОЧИСТИТЬ ИСТОРИЮ|기록 지우기|清除历史|清除紀錄|履歴を消去
EXPORT REPORT (.MD)|BERICHT EXPORTIEREN (.MD)|EXPORTER LE RAPPORT (.MD)|EXPORTAR INFORME (.MD)|ESPORTA RAPPORTO (.MD)|EXPORTAR RELATÓRIO (.MD)|ЭКСПОРТ ОТЧЁТА (.MD)|보고서 내보내기 (.MD)|导出报告 (.MD)|匯出報告 (.MD)|レポート出力 (.MD)
LIVE NAVIGATION TELEMETRY|AKTUELLE NAVIGATIONSDATEN|TÉLÉMÉTRIE DE NAVIGATION|TELEMETRÍA DE NAVEGACIÓN|TELEMETRIA DI NAVIGAZIONE|TELEMETRIA DE NAVEGAÇÃO|ТЕЛЕМЕТРИЯ НАВИГАЦИИ|실시간 탐색 측정값|实时导航遥测|即時導航遙測|ナビゲーション測定値
ONE-TIME COMPANION SETUP|BEGLEITPROGRAMM EINRICHTEN|INSTALLATION INITIALE DU COMPAGNON|INSTALACIÓN INICIAL DEL ASISTENTE|CONFIGURAZIONE INIZIALE ASSISTENTE|CONFIGURAÇÃO INICIAL DO AUXILIAR|ПЕРВИЧНАЯ НАСТРОЙКА ПОМОЩНИКА|도우미 초기 설정|辅助程序初始设置|輔助程式初始設定|補助アプリの初期設定
CUSTOMER FOLDER: LUA + MARKDOWN ONLY|KUNDENORDNER: NUR LUA + MARKDOWN|DOSSIER CLIENT : LUA + MARKDOWN|CARPETA CLIENTE: LUA + MARKDOWN|CARTELLA CLIENTE: LUA + MARKDOWN|PASTA CLIENTE: LUA + MARKDOWN|ПАПКА КЛИЕНТА: LUA + MARKDOWN|고객 폴더: LUA + MARKDOWN|用户文件夹：仅 LUA + MARKDOWN|使用者資料夾：僅 LUA + MARKDOWN|利用者フォルダー：LUA + MARKDOWN
TEST LOCAL COMPANION|LOKALES BEGLEITPROGRAMM TESTEN|TESTER LE COMPAGNON LOCAL|PROBAR ASISTENTE LOCAL|PROVA ASSISTENTE LOCALE|TESTAR AUXILIAR LOCAL|ПРОВЕРИТЬ ПОМОЩНИКА|로컬 도우미 테스트|测试本地辅助程序|測試本機輔助程式|補助アプリをテスト
ON|AN|ACTIF|SÍ|SÌ|SIM|ВКЛ|켜짐|开|開|オン
OFF|AUS|INACTIF|NO|NO|NÃO|ВЫКЛ|꺼짐|关|關|オフ
ONLINE|VERBUNDEN|EN LIGNE|EN LÍNEA|ONLINE|CONECTADO|В СЕТИ|온라인|在线|上線|オンライン
OFFLINE|GETRENNT|HORS LIGNE|SIN CONEXIÓN|OFFLINE|DESCONECTADO|НЕ В СЕТИ|오프라인|离线|離線|オフライン
ONLINE / LOCAL|LOKAL VERBUNDEN|CONNECTÉ LOCALEMENT|CONECTADO LOCALMENTE|CONNESSO LOCALMENTE|CONECTADO LOCALMENTE|ЛОКАЛЬНОЕ СОЕДИНЕНИЕ|로컬 연결됨|本地已连接|本機已連線|ローカル接続中
OFFLINE / WAITING|GETRENNT / WARTEN|DÉCONNECTÉ / EN ATTENTE|DESCONECTADO / ESPERANDO|DISCONNESSO / IN ATTESA|DESCONECTADO / AGUARDANDO|НЕТ СВЯЗИ / ОЖИДАНИЕ|연결 안 됨 / 대기|离线 / 等待|離線 / 等待|オフライン／待機中
Companion server|Begleitserver|Serveur compagnon|Servidor auxiliar|Server assistente|Servidor auxiliar|Сервер помощника|도우미 서버|辅助服务器|輔助伺服器|補助サーバー
Active owner|Aktiver Besitzer|Propriétaire actif|Propietario activo|Proprietario attivo|Responsável ativo|Активный владелец|활성 소유자|当前控制方|目前控制方|現在の制御元
Route state|Routenstatus|État du parcours|Estado de la ruta|Stato percorso|Estado da rota|Состояние маршрута|경로 상태|路线状态|路線狀態|経路状態
Recovery phase|Wiederherstellungsphase|Phase de reprise|Fase de recuperación|Fase di ripristino|Fase de recuperação|Фаза восстановления|복구 단계|恢复阶段|恢復階段|復旧段階
Selected automatically|Automatisch ausgewählt|Sélection automatique|Selección automática|Selezione automatica|Seleção automática|Выбрано автоматически|자동 선택|自动选择|自動選取|自動選択
Movement mode|Bewegungsmodus|Mode de déplacement|Modo de movimiento|Modalità movimento|Modo de movimento|Режим движения|이동 모드|移动模式|移動模式|移動モード
Guarded path queries|Geschützte Pfadanfragen|Requêtes de chemin protégées|Consultas de ruta protegidas|Richieste percorso protette|Consultas de rota protegidas|Защищённые запросы пути|보호된 경로 쿼리|受保护路径查询|受保護路徑查詢|保護付き経路クエリ
Planning mean / max|Planung Mittel / Maximum|Planification moyenne / max|Planificación media / máx.|Pianificazione media / max|Planejamento médio / máx.|Планирование: среднее / макс.|계획 평균 / 최대|规划平均 / 最大|規劃平均 / 最大|計画時間 平均／最大
Bridge path requests|Brücken-Pfadanfragen|Requêtes de chemin du pont|Solicitudes de ruta del puente|Richieste percorso del bridge|Solicitações de rota da ponte|Запросы пути через мост|브리지 경로 요청|桥接路径请求|橋接路徑請求|ブリッジ経路要求
Bridge mean RPC|Brücke mittlere RPC-Zeit|RPC moyen du pont|RPC medio del puente|RPC medio del bridge|RPC médio da ponte|Среднее время RPC моста|브리지 평균 RPC|桥接平均 RPC|橋接平均 RPC|ブリッジ平均 RPC
Recovery verified / failed|Wiederherstellung bestätigt / fehlgeschlagen|Reprises validées / échouées|Recuperaciones verificadas / fallidas|Ripristini verificati / falliti|Recuperações verificadas / falhas|Восстановление: успех / сбой|복구 확인 / 실패|恢复验证 / 失败|恢復驗證 / 失敗|復旧 成功／失敗
Loops / target updates|Schleifen / Zielaktualisierungen|Boucles / actualisations de cible|Bucles / actualizaciones de objetivo|Cicli / aggiornamenti obiettivo|Ciclos / atualizações de alvo|Циклы / обновления цели|반복 / 대상 갱신|循环 / 目标更新|循環 / 目標更新|ループ／目標更新
Tile cache hits / misses|Kachelcache Treffer / Fehler|Cache des tuiles : succès / échecs|Caché de mosaicos: aciertos / fallos|Cache riquadri: successi / mancate|Cache de blocos: acertos / falhas|Кэш тайлов: попадания / промахи|타일 캐시 적중 / 실패|区块缓存命中 / 未命中|區塊快取命中 / 未命中|タイルキャッシュ ヒット／ミス
Priority / queue / confidence|Priorität / Warteschlange / Vertrauen|Priorité / file / confiance|Prioridad / cola / confianza|Priorità / coda / affidabilità|Prioridade / fila / confiança|Приоритет / очередь / достоверность|우선순위 / 대기열 / 신뢰도|优先级 / 队列 / 置信度|優先級 / 佇列 / 信賴度|優先度／待ち行列／信頼度
None|Keine|Aucun|Ninguno|Nessuno|Nenhum|Нет|없음|无|無|なし
Unknown|Unbekannt|Inconnu|Desconocido|Sconosciuto|Desconhecido|Неизвестно|알 수 없음|未知|未知|不明
Idle|Leerlauf|Inactif|Inactivo|Inattivo|Inativo|Ожидание|유휴|空闲|閒置|待機
Ready|Bereit|Prêt|Listo|Pronto|Pronto|Готово|준비됨|就绪|就緒|準備完了
Checking|Prüfung läuft|Vérification|Comprobando|Verifica|Verificando|Проверка|확인 중|检查中|檢查中|確認中
Not checked|Nicht geprüft|Non vérifié|Sin comprobar|Non verificato|Não verificado|Не проверено|미확인|未检查|未檢查|未確認
Not loaded|Nicht geladen|Non chargé|No cargado|Non caricato|Não carregado|Не загружено|로드되지 않음|未加载|未載入|未読み込み
Not measured|Nicht gemessen|Non mesuré|Sin medir|Non misurato|Não medido|Не измерено|미측정|未测量|未測量|未測定
Waiting|Warten|En attente|Esperando|In attesa|Aguardando|Ожидание|대기 중|等待|等待|待機中
Waiting for status|Warte auf Status|En attente du statut|Esperando estado|In attesa dello stato|Aguardando estado|Ожидание состояния|상태 대기 중|等待状态|等待狀態|状態を待機中
Planning|Planung|Planification|Planificando|Pianificazione|Planejando|Планирование|계획 중|规划中|規劃中|計画中
Walking|Gehen|Marche|Caminando|In cammino|Caminhando|Движение|이동 중|行走中|行走中|移動中
Following|Folgen|Suivi|Siguiendo|Inseguimento|Seguindo|Следование|추적 중|跟随中|跟隨中|追従中
Recovering|Wiederherstellung|Reprise|Recuperando|Ripristino|Recuperando|Восстановление|복구 중|恢复中|恢復中|復旧中
Preflight|Vorprüfung|Vérifications préalables|Comprobaciones previas|Verifica preliminare|Verificação prévia|Предварительная проверка|사전 점검|预检|預檢|事前確認
Safety hold|Sicherheitsstopp|Pause de sécurité|Pausa de seguridad|Pausa di sicurezza|Pausa de segurança|Безопасная пауза|안전 대기|安全暂停|安全暫停|安全のため停止
Paused|Pausiert|En pause|En pausa|In pausa|Pausado|Пауза|일시 정지됨|已暂停|已暫停|一時停止中
Server unavailable|Server nicht verfügbar|Serveur indisponible|Servidor no disponible|Server non disponibile|Servidor indisponível|Сервер недоступен|서버 사용 불가|服务器不可用|伺服器無法使用|サーバー利用不可
Server timeout|Server-Zeitüberschreitung|Délai du serveur dépassé|Tiempo de espera agotado|Timeout del server|Tempo do servidor esgotado|Сервер не ответил вовремя|서버 시간 초과|服务器超时|伺服器逾時|サーバー応答時間超過
Map not loaded|Karte nicht geladen|Carte non chargée|Mapa no cargado|Mappa non caricata|Mapa não carregado|Карта не загружена|지도 로드 안 됨|地图未加载|地圖未載入|マップ未読み込み
Map tiles missing|Kartenkacheln fehlen|Tuiles de carte manquantes|Faltan mosaicos del mapa|Riquadri mappa mancanti|Blocos de mapa ausentes|Отсутствуют тайлы карты|지도 타일 누락|地图区块缺失|地圖區塊缺失|マップタイル不足
Version mismatch|Versionskonflikt|Versions incompatibles|Versiones incompatibles|Versioni incompatibili|Versões incompatíveis|Несовпадение версий|버전 불일치|版本不匹配|版本不相符|バージョン不一致
Bridge upgrade required|Brücken-Update erforderlich|Mise à jour du pont requise|Actualizar puente|Aggiornamento bridge richiesto|Atualização da ponte necessária|Требуется обновление моста|브리지 업데이트 필요|需要更新桥接程序|需要更新橋接程式|ブリッジ更新が必要
HTTP unavailable|HTTP nicht verfügbar|HTTP indisponible|HTTP no disponible|HTTP non disponibile|HTTP indisponível|HTTP недоступен|HTTP 사용 불가|HTTP 不可用|HTTP 無法使用|HTTP 利用不可
Context changed|Kontext geändert|Contexte modifié|Contexto cambiado|Contesto cambiato|Contexto alterado|Контекст изменён|환경 변경됨|环境已更改|環境已變更|環境が変更されました
Owner expired|Besitzer abgelaufen|Propriétaire expiré|Propietario caducado|Proprietario scaduto|Responsável expirado|Срок владения истёк|소유 기간 만료|控制权已过期|控制權已過期|制御権が失効
Interface language|Sprache der Oberfläche|Langue de l'interface|Idioma de la interfaz|Lingua dell'interfaccia|Idioma da interface|Язык интерфейса|인터페이스 언어|界面语言|介面語言|表示言語
Automatic detection when available; English fallback for missing translations.|Automatische Erkennung, falls verfügbar; fehlende Texte auf Englisch.|Détection automatique si disponible ; anglais si traduction absente.|Detección automática si está disponible; inglés si falta traducción.|Rilevamento automatico se disponibile; inglese per testi non tradotti.|Detecção automática quando disponível; inglês quando faltar tradução.|Автоопределение, если доступно; английский для отсутствующих переводов.|가능하면 자동 감지하며 번역이 없으면 영어로 표시합니다.|可用时自动检测；缺少翻译时显示英语。|可用時自動偵測；缺少翻譯時顯示英語。|可能なら自動検出し、未翻訳の文は英語で表示します。
Command sent.|Befehl gesendet.|Commande envoyée.|Comando enviado.|Comando inviato.|Comando enviado.|Команда отправлена.|명령을 보냈습니다.|指令已发送。|指令已傳送。|コマンドを送信しました。
Navigation command sent.|Navigationsbefehl gesendet.|Commande de navigation envoyée.|Comando de navegación enviado.|Comando di navigazione inviato.|Comando de navegação enviado.|Команда навигации отправлена.|탐색 명령을 보냈습니다.|导航指令已发送。|導航指令已傳送。|ナビゲーションコマンドを送信しました。
Action unavailable|Aktion nicht verfügbar|Action indisponible|Acción no disponible|Azione non disponibile|Ação indisponível|Действие недоступно|동작 사용 불가|操作不可用|操作無法使用|操作できません
Client not loaded|Client nicht geladen|Client non chargé|Cliente no cargado|Client non caricato|Cliente não carregado|Клиент не загружен|클라이언트 로드 안 됨|客户端未加载|用戶端未載入|クライアント未読み込み
Client not loaded.|Client nicht geladen.|Client non chargé.|Cliente no cargado.|Client non caricato.|Cliente não carregado.|Клиент не загружен.|클라이언트가 로드되지 않았습니다.|客户端未加载。|用戶端未載入。|クライアントが未読み込みです。
No installed combat plugin|Kein Kampf-Plugin installiert|Aucun plugin de combat installé|No hay plugin de combate instalado|Nessun plugin di combattimento installato|Nenhum plugin de combate instalado|Боевой плагин не установлен|설치된 전투 플러그인 없음|未安装战斗插件|未安裝戰鬥外掛|戦闘プラグイン未導入
No combat suite is installed for this class.|Für diese Klasse ist kein Kampf-Plugin installiert.|Aucun module de combat pour cette classe.|No hay módulo de combate para esta clase.|Nessun modulo di combattimento per questa classe.|Nenhum módulo de combate para esta classe.|Для этого класса нет боевого плагина.|이 직업의 전투 플러그인이 없습니다.|此职业未安装战斗插件。|此職業未安裝戰鬥外掛。|このクラスの戦闘プラグインがありません。
Load the matching class plugin to expose its live controls.|Passendes Klassen-Plugin laden, um seine Steuerung anzuzeigen.|Chargez le plugin de classe pour afficher ses commandes.|Carga el plugin de clase para mostrar sus controles.|Carica il plugin di classe per visualizzare i controlli.|Carregue o plugin da classe para exibir seus controles.|Загрузите плагин класса для доступа к управлению.|직업 플러그인을 로드하여 제어 항목을 표시하세요.|加载对应职业插件以显示实时控制项。|載入對應職業外掛以顯示即時控制項。|クラスのプラグインを読み込むと操作項目が表示されます。
Hotkeys appear when the matching combat plugin is loaded.|Tastenkürzel erscheinen nach dem Laden des Kampf-Plugins.|Les raccourcis apparaissent après chargement du plugin de combat.|Los atajos aparecen al cargar el plugin de combate.|Le scorciatoie appaiono caricando il plugin di combattimento.|Os atalhos aparecem ao carregar o plugin de combate.|Клавиши появятся после загрузки боевого плагина.|전투 플러그인을 로드하면 단축키가 표시됩니다.|加载对应战斗插件后显示快捷键。|載入對應戰鬥外掛後顯示快捷鍵。|戦闘プラグインの読み込み後にキーを表示します。
Class and specialization are checked continuously. Spec swaps update this page automatically.|Klasse und Spezialisierung werden laufend geprüft. Wechsel aktualisieren diese Seite.|Classe et spécialisation vérifiées en continu ; cette page se met à jour automatiquement.|La clase y especialización se comprueban continuamente; la página se actualiza automáticamente.|Classe e specializzazione vengono controllate continuamente; la pagina si aggiorna automaticamente.|Classe e especialização são verificadas continuamente; a página atualiza automaticamente.|Класс и специализация проверяются постоянно; страница обновляется автоматически.|직업과 전문화를 계속 확인하며 변경 시 자동으로 갱신합니다.|持续检测职业与专精，切换后自动更新此页面。|持續偵測職業與專精，切換後自動更新此頁面。|クラスと専門分野を継続確認し、変更時に自動更新します。
Not available. Load the matching plugin first.|Nicht verfügbar. Zuerst das passende Plugin laden.|Indisponible. Chargez d'abord le plugin correspondant.|No disponible. Carga primero el plugin correspondiente.|Non disponibile. Carica prima il plugin corrispondente.|Indisponível. Carregue primeiro o plugin correspondente.|Недоступно. Сначала загрузите нужный плагин.|사용할 수 없습니다. 해당 플러그인을 먼저 로드하세요.|不可用。请先加载对应插件。|無法使用。請先載入對應外掛。|対応するプラグインを先に読み込んでください。
No navigation owner. Start BG Player or the Leveler first.|Kein Navigationsbesitzer. Zuerst BG Player oder Leveler starten.|Aucun propriétaire de navigation. Lancez BG Player ou le Leveler.|Sin propietario. Inicia primero BG Player o el Leveler.|Nessun proprietario. Avvia prima BG Player o il Leveler.|Sem responsável. Inicie primeiro BG Player ou o Leveler.|Нет владельца навигации. Запустите BG Player или Leveler.|탐색 소유자가 없습니다. BG Player나 Leveler를 먼저 시작하세요.|没有导航控制方。请先启动 BG Player 或 Leveler。|沒有導航控制方。請先啟動 BG Player 或 Leveler。|BG Player または Leveler を先に開始してください。
Navigation client unavailable.|Navigationsclient nicht verfügbar.|Client de navigation indisponible.|Cliente de navegación no disponible.|Client di navigazione non disponibile.|Cliente de navegação indisponível.|Клиент навигации недоступен.|탐색 클라이언트를 사용할 수 없습니다.|导航客户端不可用。|導航用戶端無法使用。|ナビゲーションクライアントを利用できません。
Server connection healthy.|Serververbindung ist in Ordnung.|Connexion au serveur correcte.|Conexión al servidor correcta.|Connessione al server funzionante.|Conexão ao servidor normal.|Соединение с сервером исправно.|서버 연결이 정상입니다.|服务器连接正常。|伺服器連線正常。|サーバー接続は正常です。
Server unavailable. Check the companion.|Server nicht verfügbar. Begleitprogramm prüfen.|Serveur indisponible. Vérifiez le compagnon.|Servidor no disponible. Revisa el asistente.|Server non disponibile. Controlla l'assistente.|Servidor indisponível. Verifique o auxiliar.|Сервер недоступен. Проверьте помощник.|서버를 사용할 수 없습니다. 도우미를 확인하세요.|服务器不可用。请检查辅助程序。|伺服器無法使用。請檢查輔助程式。|サーバーを利用できません。補助アプリを確認してください。
Checking local server...|Lokaler Server wird geprüft...|Vérification du serveur local...|Comprobando servidor local...|Verifica server locale...|Verificando servidor local...|Проверка локального сервера...|로컬 서버 확인 중...|正在检查本地服务器…|正在檢查本機伺服器…|ローカルサーバーを確認中…
Enhancements not loaded.|Erweiterungen nicht geladen.|Extensions non chargées.|Mejoras no cargadas.|Miglioramenti non caricati.|Melhorias não carregadas.|Улучшения не загружены.|확장 기능이 로드되지 않았습니다.|增强功能未加载。|增強功能未載入。|拡張機能が未読み込みです。
Enhancements unavailable.|Erweiterungen nicht verfügbar.|Extensions indisponibles.|Mejoras no disponibles.|Miglioramenti non disponibili.|Melhorias indisponíveis.|Улучшения недоступны.|확장 기능을 사용할 수 없습니다.|增强功能不可用。|增強功能無法使用。|拡張機能を利用できません。
Overlay updated.|Anzeige aktualisiert.|Affichage mis à jour.|Superposición actualizada.|Visualizzazione aggiornata.|Sobreposição atualizada.|Отображение обновлено.|표시가 갱신되었습니다.|叠加显示已更新。|疊加顯示已更新。|重ね表示を更新しました。
Watchdog timing updated.|Überwachungszeit aktualisiert.|Délai de surveillance mis à jour.|Tiempo de vigilancia actualizado.|Tempo di sorveglianza aggiornato.|Tempo de monitoramento atualizado.|Время контроля обновлено.|감시 시간이 갱신되었습니다.|监测时间已更新。|監測時間已更新。|監視間隔を更新しました。
Maximum replans updated.|Maximale Neuplanungen aktualisiert.|Limite de recalculs mise à jour.|Máximo de recálculos actualizado.|Numero massimo di ricalcoli aggiornato.|Limite de recálculos atualizado.|Лимит перестроений обновлён.|최대 재계획 횟수가 갱신되었습니다.|最大重新规划次数已更新。|最大重新規劃次數已更新。|再計画上限を更新しました。
Persistence unavailable.|Speicherung nicht verfügbar.|Persistance indisponible.|Persistencia no disponible.|Persistenza non disponibile.|Persistência indisponível.|Сохранение недоступно.|저장 기능을 사용할 수 없습니다.|持久保存不可用。|持續儲存無法使用。|永続保存を利用できません。
Learned stall history cleared.|Gelernter Stillstandsverlauf gelöscht.|Historique des blocages effacé.|Historial de bloqueos borrado.|Cronologia blocchi cancellata.|Histórico de travamentos limpo.|История застреваний очищена.|학습된 정체 기록을 지웠습니다.|已清除学习到的停滞历史。|已清除學習到的停滯紀錄。|停止地点の履歴を消去しました。
Report unavailable.|Bericht nicht verfügbar.|Rapport indisponible.|Informe no disponible.|Rapporto non disponibile.|Relatório indisponível.|Отчёт недоступен.|보고서를 사용할 수 없습니다.|报告不可用。|報告無法使用。|レポートを利用できません。
Ready. Choose a module or navigation tab.|Bereit. Modul oder Navigationstab auswählen.|Prêt. Choisissez un module ou un onglet.|Listo. Elige un módulo o pestaña de navegación.|Pronto. Scegli un modulo o una scheda.|Pronto. Escolha um módulo ou aba.|Готово. Выберите модуль или вкладку.|준비됨. 모듈이나 탐색 탭을 선택하세요.|已就绪。请选择模块或导航选项卡。|已就緒。請選擇模組或導航分頁。|モジュールまたはタブを選択してください。
Learned hazards expire automatically. Recovery never changes bot combat settings.|Gelernte Gefahren laufen automatisch ab. Kampfoptionen bleiben unverändert.|Les risques mémorisés expirent automatiquement, sans modifier le combat.|Los riesgos aprendidos caducan automáticamente sin cambiar el combate.|I pericoli appresi scadono automaticamente senza modificare il combattimento.|Riscos aprendidos expiram automaticamente sem alterar o combate.|Опасные места забываются автоматически; боевые настройки не меняются.|학습한 위험 지점은 자동 만료되며 전투 설정은 변경되지 않습니다.|学习到的危险地点会自动过期，恢复功能不会更改战斗设置。|學習到的危險地點會自動過期，恢復功能不會變更戰鬥設定。|危険地点は自動で期限切れとなり、戦闘設定は変更しません。
Install the separate ArthasNav companion package.|Separates ArthasNav-Begleitpaket installieren.|Installez le compagnon ArthasNav séparé.|Instala el paquete auxiliar ArthasNav.|Installa il pacchetto assistente ArthasNav separato.|Instale o pacote auxiliar ArthasNav separado.|Установите отдельный пакет помощника ArthasNav.|별도 ArthasNav 도우미 패키지를 설치하세요.|安装独立的 ArthasNav 辅助程序包。|安裝獨立的 ArthasNav 輔助程式套件。|別配布の ArthasNav 補助アプリを導入してください。
Run Install-ArthasNav.cmd once as the customer.|Install-ArthasNav.cmd einmal als Benutzer ausführen.|Exécutez Install-ArthasNav.cmd une fois en tant qu'utilisateur.|Ejecuta Install-ArthasNav.cmd una vez como usuario.|Esegui Install-ArthasNav.cmd una volta come utente.|Execute Install-ArthasNav.cmd uma vez como usuário.|Один раз запустите Install-ArthasNav.cmd от имени пользователя.|사용자 계정으로 Install-ArthasNav.cmd를 한 번 실행하세요.|以用户身份运行一次 Install-ArthasNav.cmd。|以使用者身分執行一次 Install-ArthasNav.cmd。|利用者アカウントで Install-ArthasNav.cmd を一度実行してください。
Keep MasterArthasNav beside BG Player and the 1-90 Leveler.|MasterArthasNav neben BG Player und 1–90 Leveler installieren.|Gardez MasterArthasNav avec BG Player et le Leveler 1–90.|Mantén MasterArthasNav junto a BG Player y Leveler 1–90.|Mantieni MasterArthasNav accanto a BG Player e Leveler 1–90.|Mantenha MasterArthasNav com BG Player e Leveler 1–90.|Разместите MasterArthasNav рядом с BG Player и Leveler 1–90.|MasterArthasNav를 BG Player 및 1–90 Leveler와 함께 두세요.|将 MasterArthasNav 与 BG Player 和 1–90 Leveler 放在一起。|將 MasterArthasNav 與 BG Player 和 1–90 Leveler 放在一起。|BG Player と 1–90 Leveler と同じ場所に配置してください。
Start the desired bot from its own module panel.|Gewünschten Bot in seinem Modul starten.|Lancez le bot depuis son propre module.|Inicia el bot desde su propio módulo.|Avvia il bot dal suo modulo.|Inicie o bot pelo próprio módulo.|Запустите бота из его модуля.|해당 모듈 패널에서 봇을 시작하세요.|从对应模块面板启动所需程序。|從對應模組面板啟動所需程式。|各モジュールのパネルから開始してください。
The local helper supplies maps and path calculations automatically.|Das lokale Hilfsprogramm liefert Karten und Pfadberechnungen automatisch.|L'assistant local fournit cartes et calculs de chemins automatiquement.|El asistente local proporciona mapas y rutas automáticamente.|L'assistente locale fornisce mappe e percorsi automaticamente.|O auxiliar local fornece mapas e rotas automaticamente.|Локальный помощник автоматически предоставляет карты и расчёт пути.|로컬 도우미가 지도와 경로 계산을 자동으로 제공합니다.|本地辅助程序会自动提供地图和路径计算。|本機輔助程式會自動提供地圖與路徑計算。|補助アプリがマップと経路計算を自動提供します。
Use Check Local Connection in Route Control.|Lokale Verbindung unter Routensteuerung prüfen.|Utilisez Vérifier la liaison locale dans le contrôle du parcours.|Usa Comprobar conexión local en Control de ruta.|Usa Verifica connessione locale in Controllo percorso.|Use Verificar conexão local no Controle de rota.|Нажмите проверку связи в управлении маршрутом.|경로 제어에서 로컬 연결 확인을 사용하세요.|请在路线控制中使用“检查本地连接”。|請在路線控制中使用「檢查本機連線」。|ルート制御の「ローカル接続を確認」を使用してください。
Battleground and leveling launch controls|Schlachtfeld- und Leveler-Startsteuerung|Commandes de lancement du champ de bataille et de progression|Controles de inicio de campo de batalla y subida de nivel|Comandi di avvio campo di battaglia e livellamento|Controles de início de campo de batalha e evolução|Запуск поля боя и прокачки|전장 및 레벨업 실행 제어|战场与升级启动控制|戰場與升級啟動控制|戦場とレベル上げの開始操作
Automatic class, specialization, plugin and hotkey control|Automatische Klassen-, Spezialisierungs- und Tastensteuerung|Contrôle automatique de classe, spécialisation et raccourcis|Control automático de clase, especialización y atajos|Controllo automatico di classe, specializzazione e scorciatoie|Controle automático de classe, especialização e atalhos|Автовыбор класса, специализации и клавиш|직업, 전문화, 플러그인 및 단축키 자동 제어|自动控制职业、专精、插件与快捷键|自動控制職業、專精、外掛與快捷鍵|クラス・専門分野・キーの自動設定
Live path control and navigation state|Live-Pfadsteuerung und Navigationsstatus|Contrôle du chemin et état de navigation en direct|Control de ruta y estado de navegación en vivo|Controllo percorso e stato navigazione in tempo reale|Controle de rota e estado de navegação em tempo real|Управление путём и состояние навигации|실시간 경로 제어 및 탐색 상태|实时路径控制与导航状态|即時路徑控制與導航狀態|経路操作とナビゲーション状態
Watchdogs, replans and learned hazards|Überwachung, Neuplanung und gelernte Gefahren|Surveillance, recalculs et risques mémorisés|Vigilancia, recálculos y riesgos aprendidos|Sorveglianza, ricalcoli e pericoli appresi|Monitoramento, recálculos e riscos aprendidos|Контроль застреваний, перестроение и опасные места|감시, 재계획 및 학습된 위험|监测、重新规划与学习到的危险|監測、重新規劃與學習到的危險|監視・再計画・学習した危険地点
Recovery report and customer support export|Wiederherstellungsbericht für den Kundendienst|Rapport de reprise à exporter pour l'assistance|Informe de recuperación para soporte|Rapporto di ripristino per l'assistenza|Relatório de recuperação para suporte|Отчёт восстановления для поддержки|복구 보고서 및 고객 지원 내보내기|恢复报告与客户支持导出|恢復報告與客戶支援匯出|復旧レポートとサポート用出力
Planner, bridge and recovery measurements|Planungs-, Brücken- und Wiederherstellungswerte|Mesures du planificateur, du pont et de la reprise|Mediciones de planificación, puente y recuperación|Misure di pianificazione, bridge e ripristino|Medições de planejamento, ponte e recuperação|Показатели планирования, моста и восстановления|계획기, 브리지 및 복구 측정값|规划器、桥接与恢复指标|規劃器、橋接與恢復指標|計画・ブリッジ・復旧の測定値
Local companion installation and health checks|Installation und Prüfung des Begleitprogramms|Installation et vérifications du compagnon local|Instalación y comprobación del asistente local|Installazione e verifica dell'assistente locale|Instalação e verificação do auxiliar local|Установка и проверка локального помощника|로컬 도우미 설치 및 상태 점검|本地辅助程序安装与健康检查|本機輔助程式安裝與健康檢查|補助アプリの導入と動作確認
Open MasterArthasNav Command Center|MasterArthasNav-Befehlszentrale öffnen|Ouvrir le centre de commande MasterArthasNav|Abrir centro de mando MasterArthasNav|Apri centro di comando MasterArthasNav|Abrir centro de comando MasterArthasNav|Открыть центр управления MasterArthasNav|MasterArthasNav 명령 센터 열기|打开 MasterArthasNav 指挥中心|開啟 MasterArthasNav 指揮中心|MasterArthasNav コマンドセンターを開く
Tabbed navigation and auto-detected combat controls.|Navigation mit Tabs und automatischer Kampferkennung.|Navigation par onglets et détection des commandes de combat.|Navegación por pestañas y controles de combate automáticos.|Navigazione a schede e controlli di combattimento automatici.|Navegação por abas e controles de combate automáticos.|Вкладки навигации и автоматические боевые настройки.|탭 탐색 및 자동 감지된 전투 제어.|分组选项卡导航与自动检测战斗控制。|分頁導航與自動偵測戰鬥控制。|タブ式ナビゲーションと自動検出の戦闘設定。
PLUGIN ENABLED|PLUGIN AKTIV|PLUGIN ACTIVÉ|PLUGIN ACTIVADO|PLUGIN ATTIVO|PLUGIN ATIVO|ПЛАГИН ВКЛЮЧЁН|플러그인 활성화|启用插件|啟用外掛|プラグイン有効
PAUSE ALL ACTIONS|ALLE AKTIONEN PAUSIEREN|SUSPENDRE TOUTES LES ACTIONS|PAUSAR TODAS LAS ACCIONES|SOSPENDI TUTTE LE AZIONI|PAUSAR TODAS AS AÇÕES|ПРИОСТАНОВИТЬ ВСЕ ДЕЙСТВИЯ|모든 동작 일시 정지|暂停所有操作|暫停所有操作|全動作を一時停止
SHOW WARRIOR GUI|KRIEGER-GUI ANZEIGEN|AFFICHER L'INTERFACE GUERRIER|MOSTRAR INTERFAZ GUERRERO|MOSTRA INTERFACCIA GUERRIERO|MOSTRAR INTERFACE GUERREIRO|ПОКАЗАТЬ ИНТЕРФЕЙС ВОИНА|전사 GUI 표시|显示战士界面|顯示戰士介面|ウォリアー画面を表示
SHOW HUNTER GUI|JÄGER-GUI ANZEIGEN|AFFICHER L'INTERFACE CHASSEUR|MOSTRAR INTERFAZ CAZADOR|MOSTRA INTERFACCIA CACCIATORE|MOSTRAR INTERFACE CAÇADOR|ПОКАЗАТЬ ИНТЕРФЕЙС ОХОТНИКА|사냥꾼 GUI 표시|显示猎人界面|顯示獵人介面|ハンター画面を表示
SHOW MAGE GUI|MAGIER-GUI ANZEIGEN|AFFICHER L'INTERFACE MAGE|MOSTRAR INTERFAZ MAGO|MOSTRA INTERFACCIA MAGO|MOSTRAR INTERFACE MAGO|ПОКАЗАТЬ ИНТЕРФЕЙС МАГА|마법사 GUI 표시|显示法师界面|顯示法師介面|メイジ画面を表示
SHOW CLASS GUI|KLASSEN-GUI ANZEIGEN|AFFICHER L'INTERFACE DE CLASSE|MOSTRAR INTERFAZ DE CLASE|MOSTRA INTERFACCIA DI CLASSE|MOSTRAR INTERFACE DA CLASSE|ПОКАЗАТЬ ИНТЕРФЕЙС КЛАССА|직업 GUI 표시|显示职业界面|顯示職業介面|クラス画面を表示
SHOW PROTECTION GUI|SCHUTZ-GUI ANZEIGEN|AFFICHER L'INTERFACE PROTECTION|MOSTRAR INTERFAZ PROTECCIÓN|MOSTRA INTERFACCIA PROTEZIONE|MOSTRAR INTERFACE PROTEÇÃO|ПОКАЗАТЬ ИНТЕРФЕЙС ЗАЩИТЫ|보호 GUI 표시|显示防护界面|顯示防護介面|プロテクション画面を表示
ALLOW PVP BURST|PVP-BURST ERLAUBEN|AUTORISER LE BURST JcJ|PERMITIR RÁFAGA JcJ|CONSENTI BURST PvP|PERMITIR EXPLOSÃO JxJ|РАЗРЕШИТЬ PVP-БУРСТ|PVP 폭딜 허용|允许 PVP 爆发|允許 PVP 爆發|PVP バースト許可
BOSS GUIDE|BOSS-HILFE|GUIDE DU BOSS|GUÍA DE JEFE|GUIDA BOSS|GUIA DE CHEFE|ПОДСКАЗКИ БОССА|우두머리 가이드|首领指南|首領指南|ボスガイド
DIAGNOSTICS|DIAGNOSE|DIAGNOSTIC|DIAGNÓSTICO|DIAGNOSTICA|DIAGNÓSTICO|ДИАГНОСТИКА|진단|诊断|診斷|診断
TRAINING DUMMY|TRAININGSPUPPE|MANNEQUIN D'ENTRAÎNEMENT|MUÑECO DE ENTRENAMIENTO|MANICHINO DI ALLENAMENTO|BONECO DE TREINO|ТРЕНИРОВОЧНЫЙ МАНЕКЕН|훈련용 허수아비|训练假人|訓練假人|訓練用ダミー
COOLDOWNS|ABKLINGZEITEN|TEMPS DE RECHARGE|REUTILIZACIONES|TEMPI DI RECUPERO|RECARGAS|ПЕРЕЗАРЯДКИ|재사용 대기시간|冷却技能|冷卻技能|クールダウン
INTERRUPTS|UNTERBRECHUNGEN|INTERRUPTIONS|INTERRUPCIONES|INTERRUZIONI|INTERRUPÇÕES|ПРЕРЫВАНИЯ|차단|打断|中斷|詠唱妨害
DAMAGE PREDICTION|SCHADENSVORHERSAGE|PRÉDICTION DES DÉGÂTS|PREDICCIÓN DE DAÑO|PREVISIONE DANNI|PREVISÃO DE DANO|ПРОГНОЗ УРОНА|피해 예측|伤害预测|傷害預測|ダメージ予測
ROUTE OVERLAY|ROUTENANZEIGE|AFFICHAGE DU PARCOURS|SUPERPOSICIÓN DE RUTA|SOVRAPPOSIZIONE PERCORSO|SOBREPOSIÇÃO DE ROTA|ОТОБРАЖЕНИЕ МАРШРУТА|경로 표시|路线叠加|路線疊加|経路の重ね表示
ENABLE HOTKEYS|TASTENKÜRZEL AKTIVIEREN|ACTIVER LES RACCOURCIS|ACTIVAR ATAJOS|ATTIVA SCORCIATOIE|ATIVAR ATALHOS|ВКЛЮЧИТЬ ГОРЯЧИЕ КЛАВИШИ|단축키 활성화|启用快捷键|啟用快捷鍵|ホットキー有効
SAFE DAMAGE|SICHERER SCHADEN|DÉGÂTS PRUDENTS|DAÑO SEGURO|DANNI SICURI|DANO SEGURO|БЕЗОПАСНЫЙ УРОН|안전한 피해|安全输出|安全輸出|安全な攻撃
HEALING COOLDOWNS|HEILUNGS-ABKLINGZEITEN|TEMPS DE RECHARGE DE SOIN|REUTILIZACIONES DE SANACIÓN|RECUPERI DI CURA|RECARGAS DE CURA|ПЕРЕЗАРЯДКИ ЛЕЧЕНИЯ|치유 재사용 대기시간|治疗冷却技能|治療冷卻技能|回復クールダウン
DEFENSIVES|DEFENSIVFÄHIGKEITEN|CAPACITÉS DÉFENSIVES|DEFENSIVOS|DIFESE|DEFENSIVOS|ЗАЩИТНЫЕ СПОСОБНОСТИ|방어 기술|防御技能|防禦技能|防御スキル
BOSS HELPER|BOSS-HELFER|ASSISTANT DE BOSS|ASISTENTE DE JEFE|ASSISTENTE BOSS|AUXILIAR DE CHEFE|ПОМОЩНИК БОССА|우두머리 도우미|首领助手|首領助手|ボス補助
DAMAGE ROTATION|SCHADENSROTATION|ROTATION DE DÉGÂTS|ROTACIÓN DE DAÑO|ROTAZIONE DANNI|ROTAÇÃO DE DANO|РОТАЦИЯ УРОНА|공격 순환|输出循环|輸出循環|攻撃ローテーション
CROWD CONTROL|MENGENKONTROLLE|CONTRÔLE DES FOULES|CONTROL DE MASAS|CONTROLLO FOLLE|CONTROLE DE GRUPO|КОНТРОЛЬ ТОЛПЫ|군중 제어|群体控制|群體控制|行動制限
UNBOUND|NICHT BELEGT|NON ASSIGNÉ|SIN ASIGNAR|NON ASSEGNATO|NÃO ATRIBUÍDO|НЕ НАЗНАЧЕНО|미지정|未绑定|未綁定|未割り当て
No character|Kein Charakter|Aucun personnage|Sin personaje|Nessun personaggio|Nenhum personagem|Нет персонажа|캐릭터 없음|无角色|無角色|キャラクターなし
No specialization|Keine Spezialisierung|Aucune spécialisation|Sin especialización|Nessuna specializzazione|Nenhuma especialização|Нет специализации|전문화 없음|无专精|無專精|専門分野なし
Warrior|Krieger|Guerrier|Guerrero|Guerriero|Guerreiro|Воин|전사|战士|戰士|ウォリアー
Paladin|Paladin|Paladin|Paladín|Paladino|Paladino|Паладин|성기사|圣骑士|聖騎士|パラディン
Hunter|Jäger|Chasseur|Cazador|Cacciatore|Caçador|Охотник|사냥꾼|猎人|獵人|ハンター
Rogue|Schurke|Voleur|Pícaro|Ladro|Ladino|Разбойник|도적|潜行者|盜賊|ローグ
Priest|Priester|Prêtre|Sacerdote|Sacerdote|Sacerdote|Жрец|사제|牧师|牧師|プリースト
Death Knight|Todesritter|Chevalier de la mort|Caballero de la Muerte|Cavaliere della Morte|Cavaleiro da Morte|Рыцарь смерти|죽음의 기사|死亡骑士|死亡騎士|デスナイト
Shaman|Schamane|Chaman|Chamán|Sciamano|Xamã|Шаман|주술사|萨满祭司|薩滿|シャーマン
Mage|Magier|Mage|Mago|Mago|Mago|Маг|마법사|法师|法師|メイジ
Warlock|Hexenmeister|Démoniste|Brujo|Stregone|Bruxo|Чернокнижник|흑마법사|术士|術士|ウォーロック
Monk|Mönch|Moine|Monje|Monaco|Monge|Монах|수도사|武僧|武僧|モンク
Druid|Druide|Druide|Druida|Druido|Druida|Друид|드루이드|德鲁伊|德魯伊|ドルイド
Demon Hunter|Dämonenjäger|Chasseur de démons|Cazador de demonios|Cacciatore di Demoni|Caçador de Demônios|Охотник на демонов|악마사냥꾼|恶魔猎手|惡魔獵人|デーモンハンター
Evoker|Rufer|Évocateur|Evocador|Evocatore|Conjurante|Пробудитель|기원사|唤魔师|喚能師|エヴォーカー
Arms|Waffen|Armes|Armas|Armi|Armas|Оружие|무기|武器|武器|武器
Fury|Furor|Fureur|Furia|Furia|Fúria|Неистовство|분노|狂怒|狂怒|激怒
Protection|Schutz|Protection|Protección|Protezione|Proteção|Защита|방어|防护|防護|防御
Holy|Heilig|Sacré|Sagrado|Sacro|Sagrado|Свет|신성|神圣|神聖|神聖
Retribution|Vergeltung|Vindicte|Reprensión|Castigo|Retribuição|Воздаяние|징벌|惩戒|懲戒|懲罰
Beast Mastery|Tierherrschaft|Maîtrise des bêtes|Bestias|Affinità Animale|Domínio das Feras|Повелитель зверей|야수|野兽控制|野獸控制|獣使い
Marksmanship|Treffsicherheit|Précision|Puntería|Precisione di Tiro|Precisão|Стрельба|사격|射击|射擊|射撃
Survival|Überleben|Survie|Supervivencia|Sopravvivenza|Sobrevivência|Выживание|생존|生存|生存|生存
Assassination|Meucheln|Assassinat|Asesinato|Assassinio|Assassinato|Ликвидация|암살|奇袭|刺殺|暗殺
Outlaw|Gesetzlosigkeit|Hors-la-loi|Forajido|Fuorilegge|Fora da Lei|Головорез|무법|狂徒|暴徒|無法者
Subtlety|Täuschung|Finesse|Sutileza|Scaltrezza|Subterfúgio|Скрытность|잠행|敏锐|敏銳|隠密
Elemental|Elementar|Élémentaire|Elemental|Elementale|Elemental|Стихии|정기|元素|元素|元素
Enhancement|Verstärkung|Amélioration|Mejora|Potenziamento|Aperfeiçoamento|Совершенствование|고양|增强|增強|強化
Restoration|Wiederherstellung|Restauration|Restauración|Rigenerazione|Restauração|Исцеление|복원|恢复|恢復|回復
Arcane|Arkan|Arcanes|Arcano|Arcano|Arcano|Тайная магия|비전|奥术|秘法|秘術
Fire|Feuer|Feu|Fuego|Fuoco|Fogo|Огонь|화염|火焰|火焰|火炎
Frost|Frost|Givre|Escarcha|Gelo|Gélido|Лёд|냉기|冰霜|冰霜|氷霜
Balance|Gleichgewicht|Équilibre|Equilibrio|Equilibrio|Equilíbrio|Баланс|조화|平衡|平衡|均衡
Feral|Wildheit|Farouche|Feral|Aggressore Ferino|Feral|Сила зверя|야성|野性|野性|野性
Guardian|Wächter|Gardien|Guardián|Guardiano|Guardião|Страж|수호|守护|守護者|守護
Stop|Stopp|Arrêter|Detener|Ferma|Parar|Стоп|정지|停止|停止|停止
Faction|Fraktion|Faction|Facción|Fazione|Facção|Фракция|진영|阵营|陣營|陣営
Follow mode|Folgemodus|Mode de suivi|Modo de seguimiento|Modalità inseguimento|Modo de seguimento|Режим следования|추적 모드|跟随模式|跟隨模式|追従モード
Debug log|Debugprotokoll|Journal de débogage|Registro de depuración|Registro di debug|Registro de depuração|Отладочный журнал|디버그 로그|调试日志|偵錯日誌|デバッグログ
Draw path|Pfad anzeigen|Afficher le chemin|Dibujar ruta|Mostra percorso|Exibir rota|Показать путь|경로 표시|显示路径|顯示路徑|経路を表示
On-screen banner|Bildschirmbanner|Bannière à l'écran|Aviso en pantalla|Avviso a schermo|Aviso na tela|Баннер на экране|화면 배너|屏幕横幅|螢幕橫幅|画面バナー
Pause while casting|Beim Zaubern pausieren|Pause pendant l'incantation|Pausar al lanzar|Pausa durante il lancio|Pausar ao lançar|Пауза при произнесении|시전 중 일시 정지|施法时暂停|施法時暫停|詠唱中は停止
Ping server|Server prüfen|Tester le serveur|Comprobar servidor|Verifica server|Verificar servidor|Проверить сервер|서버 확인|检查服务器|檢查伺服器|サーバー確認
Start following|Folgen starten|Commencer le suivi|Iniciar seguimiento|Inizia inseguimento|Começar a seguir|Начать следование|추적 시작|开始跟随|開始跟隨|追従を開始
Test: walk to my target|Test: zum Ziel gehen|Test : marcher vers ma cible|Prueba: caminar al objetivo|Prova: cammina verso il bersaglio|Teste: caminhar até o alvo|Тест: идти к моей цели|테스트: 대상에게 이동|测试：走向我的目标|測試：走向我的目標|テスト：ターゲットに移動
Check the navigation server now|Navigationsserver jetzt prüfen|Vérifier le serveur de navigation|Comprobar servidor de navegación|Verifica subito il server di navigazione|Verificar o servidor de navegação agora|Проверить сервер навигации сейчас|지금 탐색 서버 확인|立即检查导航服务器|立即檢查導航伺服器|ナビゲーションサーバーを確認
Draw the current path in the world|Aktuellen Pfad in der Welt anzeigen|Afficher le chemin actuel dans le monde|Mostrar la ruta actual en el mundo|Mostra il percorso attuale nel mondo|Exibir a rota atual no mundo|Показать текущий путь в мире|월드에 현재 경로 표시|在世界中显示当前路径|在世界中顯示目前路徑|ワールド内に現在の経路を表示
Keep re-pathing to the unit as it moves|Pfad zum beweglichen Ziel laufend erneuern|Recalculer le chemin vers l'unité en mouvement|Recalcular ruta a la unidad en movimiento|Ricalcola il percorso mentre l'unità si muove|Recalcular a rota enquanto a unidade se move|Обновлять путь при движении цели|대상이 이동하면 경로 재계산|目标移动时持续重新规划路径|目標移動時持續重新規劃路徑|対象の移動に合わせて経路を再計算
Pathfind to the current target and walk there|Pfad zum aktuellen Ziel berechnen und gehen|Calculer le chemin vers la cible puis marcher|Calcular ruta al objetivo actual y caminar|Calcola il percorso verso il bersaglio e cammina|Calcular rota até o alvo atual e caminhar|Найти путь к текущей цели и идти|현재 대상까지 경로 탐색 후 이동|寻找当前目标的路径并前往|尋找目前目標的路徑並前往|現在のターゲットへの経路を計算して移動
Print every request and state change to the console|Jede Anfrage und Statusänderung protokollieren|Afficher chaque requête et changement d'état|Registrar cada solicitud y cambio de estado|Registra ogni richiesta e cambio di stato|Registrar cada solicitação e mudança de estado|Выводить запросы и изменения состояния|모든 요청과 상태 변경을 콘솔에 표시|将所有请求与状态更改输出到控制台|將所有請求與狀態變更輸出到主控台|要求と状態変化をすべてコンソールに出力
Reach, stuck and avoidance distances: the 'Ameisen Movement' page|Reichweite und Ausweichabstände: Seite „Ameisen Movement“|Distances d'arrivée et d'évitement : page « Ameisen Movement »|Distancias de llegada y evasión: página «Ameisen Movement»|Distanze di arrivo ed evasione: pagina «Ameisen Movement»|Distâncias de chegada e desvio: página «Ameisen Movement»|Дистанции прибытия и обхода: страница «Ameisen Movement»|도착 및 회피 거리: 'Ameisen Movement' 페이지|到达、脱困与避障距离：Ameisen Movement 页面|抵達、脫困與避障距離：Ameisen Movement 頁面|到着・脱出・回避距離：「Ameisen Movement」ページ
Show a status banner while navigating or following|Statusbanner beim Navigieren oder Folgen anzeigen|Afficher une bannière pendant la navigation ou le suivi|Mostrar estado al navegar o seguir|Mostra lo stato durante navigazione o inseguimento|Exibir status durante navegação ou seguimento|Показывать состояние при движении или следовании|탐색 또는 추적 중 상태 배너 표시|导航或跟随时显示状态横幅|導航或跟隨時顯示狀態橫幅|ナビゲーション・追従中に状態バナーを表示
Stop the current navigation|Aktuelle Navigation stoppen|Arrêter la navigation actuelle|Detener navegación actual|Ferma la navigazione attuale|Parar a navegação atual|Остановить текущую навигацию|현재 탐색 정지|停止当前导航|停止目前導航|現在のナビゲーションを停止
Stop walking while casting or channelling|Beim Zaubern oder Kanalisieren anhalten|Arrêter la marche pendant l'incantation ou la canalisation|Detener marcha al lanzar o canalizar|Ferma il movimento durante lancio o canalizzazione|Parar ao lançar ou canalizar|Остановиться при произнесении или поддержании заклинания|시전 또는 정신 집중 중 이동 정지|施法或引导时停止行走|施法或引導時停止行走|詠唱・チャネリング中は移動を停止
Which faction's towns paths avoid. Auto reads the player's race|Fraktionsorte meiden. Automatik erkennt das Volk.|Villes de faction à éviter. Auto détecte la race.|Ciudades de facción a evitar. Auto detecta la raza.|Città di fazione da evitare. Auto rileva la razza.|Cidades de facção a evitar. Auto detecta a raça.|Города какой фракции обходить. Авто определяет расу.|회피할 진영 마을. 자동 모드는 종족을 감지합니다.|路径应避开的阵营城镇。自动模式读取角色种族。|路徑應避開的陣營城鎮。自動模式讀取角色種族。|回避する陣営の町。自動は種族から判定します。
Who to follow: your target, your focus, or a unit by exact name|Folgeziel: Ziel, Fokus oder exakter Einheitenname|À suivre : cible, focalisation ou nom exact|A quién seguir: objetivo, foco o nombre exacto|Chi seguire: bersaglio, focus o nome esatto|Quem seguir: alvo, foco ou nome exato|За кем следовать: цель, фокус или точное имя|추적 대상: 대상, 주시 대상 또는 정확한 이름|跟随对象：目标、焦点或精确名称|跟隨對象：目標、焦點或精確名稱|追従対象：ターゲット・フォーカス・完全一致の名前
]]
data=data..[[
HOME|START|ACCUEIL|INICIO|HOME|INÍCIO|ГЛАВНАЯ|홈|主页|首頁|ホーム
CORE|KERN|PRINCIPAL|PRINCIPAL|PRINCIPALE|PRINCIPAL|ОСНОВНОЕ|기본|核心|核心|基本
ROTATION|ROTATION|ROTATION|ROTACIÓN|ROTAZIONE|ROTAÇÃO|РОТАЦИЯ|순환|循环|循環|ローテーション
DEFENSE|VERTEIDIGUNG|DÉFENSE|DEFENSA|DIFESA|DEFESA|ЗАЩИТА|방어|防御|防禦|防御
UTILITY|NÜTZLICHES|UTILITAIRES|UTILIDAD|UTILITÀ|UTILIDADE|ПОДДЕРЖКА|유틸리티|辅助|輔助|補助
ACTIVITY|AKTIVITÄT|ACTIVITÉ|ACTIVIDAD|ATTIVITÀ|ATIVIDADE|АКТИВНОСТЬ|활동|活动|活動|アクティビティ
DUNGEONS|DUNGEONS|DONJONS|MAZMORRAS|SPEDIZIONI|MASMORRAS|ПОДЗЕМЕЛЬЯ|던전|地下城|地城|ダンジョン
PROFILES|PROFILE|PROFILS|PERFILES|PROFILI|PERFIS|ПРОФИЛИ|프로필|配置|設定檔|プロファイル
SETTINGS|EINSTELLUNGEN|PARAMÈTRES|AJUSTES|IMPOSTAZIONI|CONFIGURAÇÕES|ПАРАМЕТРЫ|설정|设置|設定|設定
HELP|HILFE|AIDE|AYUDA|AIUTO|AJUDA|СПРАВКА|도움말|帮助|說明|ヘルプ
STATUS|STATUS|ÉTAT|ESTADO|STATO|ESTADO|СОСТОЯНИЕ|상태|状态|狀態|状態
SAVE|SPEICHERN|ENREGISTRER|GUARDAR|SALVA|SALVAR|СОХРАНИТЬ|저장|保存|儲存|保存
LOAD|LADEN|CHARGER|CARGAR|CARICA|CARREGAR|ЗАГРУЗИТЬ|불러오기|加载|載入|読み込み
RESET|ZURÜCKSETZEN|RÉINITIALISER|RESTABLECER|RIPRISTINA|REDEFINIR|СБРОСИТЬ|초기화|重置|重設|リセット
START|STARTEN|DÉMARRER|INICIAR|AVVIA|INICIAR|ЗАПУСТИТЬ|시작|开始|開始|開始
CLOSE|SCHLIESSEN|FERMER|CERRAR|CHIUDI|FECHAR|ЗАКРЫТЬ|닫기|关闭|關閉|閉じる
BACK|ZURÜCK|RETOUR|VOLVER|INDIETRO|VOLTAR|НАЗАД|뒤로|返回|返回|戻る
NEXT|WEITER|SUIVANT|SIGUIENTE|AVANTI|PRÓXIMO|ДАЛЕЕ|다음|下一步|下一步|次へ
PREVIOUS|ZURÜCK|PRÉCÉDENT|ANTERIOR|PRECEDENTE|ANTERIOR|ПРЕДЫДУЩИЙ|이전|上一步|上一步|前へ
UP|HOCH|HAUT|ARRIBA|SU|CIMA|ВВЕРХ|위|上|上|上
DOWN|RUNTER|BAS|ABAJO|GIÙ|BAIXO|ВНИЗ|아래|下|下|下
MOVEMENT|BEWEGUNG|DÉPLACEMENT|MOVIMIENTO|MOVIMENTO|MOVIMENTO|ДВИЖЕНИЕ|이동|移动|移動|移動
MOBILITY|MOBILITÄT|MOBILITÉ|MOVILIDAD|MOBILITÀ|MOBILIDADE|МОБИЛЬНОСТЬ|기동성|机动|機動|機動力
HEALING|HEILUNG|SOINS|SANACIÓN|CURA|CURA|ЛЕЧЕНИЕ|치유|治疗|治療|回復
TANK|TANK|TANK|TANQUE|DIFENSORE|TANQUE|ТАНК|방어 담당|坦克|坦克|タンク
HEALER|HEILER|SOIGNEUR|SANADOR|GUARITORE|CURADOR|ЛЕКАРЬ|치유 담당|治疗者|治療者|ヒーラー
DAMAGE|SCHADEN|DÉGÂTS|DAÑO|DANNI|DANO|УРОН|피해|伤害|傷害|ダメージ
BURST|BURST|BURST|RÁFAGA|BURST|EXPLOSÃO|БУРСТ|폭딜|爆发|爆發|バースト
CONTROL|KONTROLLE|CONTRÔLE|CONTROL|CONTROLLO|CONTROLE|КОНТРОЛЬ|제어|控制|控制|制御
PET|BEGLEITER|FAMILIER|MASCOTA|FAMIGLIO|AJUDANTE|ПИТОМЕЦ|소환수|宠物|寵物|ペット
HOTKEYS|TASTENKÜRZEL|RACCOURCIS|ATAJOS|SCORCIATOIE|ATALHOS|ГОРЯЧИЕ КЛАВИШИ|단축키|快捷键|快捷鍵|ホットキー
DISPLAY / LOGS|ANZEIGE / PROTOKOLLE|AFFICHAGE / JOURNAUX|PANTALLA / REGISTROS|VISUALIZZAZIONE / REGISTRI|EXIBIÇÃO / REGISTROS|ЭКРАН / ЖУРНАЛЫ|표시 / 로그|显示 / 日志|顯示 / 日誌|表示／ログ
GATHERING|SAMMELN|RÉCOLTE|RECOLECCIÓN|RACCOLTA|COLETA|СБОР|채집|采集|採集|採集
LEVELING|STUFENAUFSTIEG|PROGRESSION|SUBIDA DE NIVEL|LIVELLAMENTO|EVOLUÇÃO|ПРОКАЧКА|레벨업|升级|升級|レベル上げ
QUESTING|QUESTEN|QUÊTES|MISIONES|MISSIONI|MISSÕES|ЗАДАНИЯ|퀘스트|任务|任務|クエスト
GRINDING|FARMEN|FARM|FARMEAR|FARMING|FARM|ФАРМ|반복 사냥|刷怪|刷怪|狩り
PROFESSIONS|BERUFE|MÉTIERS|PROFESIONES|PROFESSIONI|PROFISSÕES|ПРОФЕССИИ|전문 기술|专业|專業|生産職
GENERAL|ALLGEMEIN|GÉNÉRAL|GENERAL|GENERALE|GERAL|ОБЩЕЕ|일반|常规|一般|一般
ADVANCED|ERWEITERT|AVANCÉ|AVANZADO|AVANZATE|AVANÇADO|ДОПОЛНИТЕЛЬНО|고급|高级|進階|詳細
HEALTH|GESUNDHEIT|SANTÉ|SALUD|SALUTE|VIDA|ЗДОРОВЬЕ|생명력|生命值|生命力|体力
MANA|MANA|MANA|MANÁ|MANA|MANA|МАНА|마나|法力值|法力|マナ
Auto|Automatisch|Auto|Automático|Automatico|Automático|Авто|자동|自动|自動|自動
Target|Ziel|Cible|Objetivo|Bersaglio|Alvo|Цель|대상|目标|目標|ターゲット
Focus|Fokus|Focalisation|Foco|Focus|Foco|Фокус|주시 대상|焦点|專注目標|フォーカス
Player|Spieler|Joueur|Jugador|Giocatore|Jogador|Игрок|플레이어|玩家|玩家|プレイヤー
Group|Gruppe|Groupe|Grupo|Gruppo|Grupo|Группа|그룹|队伍|隊伍|グループ
Alliance|Allianz|Alliance|Alianza|Alleanza|Aliança|Альянс|얼라이언스|联盟|聯盟|アライアンス
Horde|Horde|Horde|Horda|Orda|Horda|Орда|호드|部落|部落|ホード
By name|Nach Name|Par nom|Por nombre|Per nome|Por nome|По имени|이름으로|按名称|依名稱|名前で指定
Enabled|Aktiviert|Activé|Activado|Attivato|Ativado|Включено|활성화됨|已启用|已啟用|有効
Disabled|Deaktiviert|Désactivé|Desactivado|Disattivato|Desativado|Выключено|비활성화됨|已禁用|已停用|無効
]]
local result={};for _,tag in ipairs(locales)do result[tag]={}end
for line in data:gmatch('[^\r\n]+')do
 local fields={};for part in (line..'|'):gmatch('(.-)|')do fields[#fields+1]=part end
 assert(#fields==#locales,'Invalid localization row: '..tostring(fields[1]))
 for i,tag in ipairs(locales)do assert(fields[i]~='','Empty translation: '..fields[1]);result[tag][fields[1]]=fields[i]end
end
return result
