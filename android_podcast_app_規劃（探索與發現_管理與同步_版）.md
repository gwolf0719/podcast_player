# Android Podcast App 規劃（探索與發現 + 管理與同步 版）

> 版本：**v1.0** — 依你拍板結果定稿。聚焦「探索與發現」與「管理與同步」。**不含進階播放體驗**（如倍速、睡眠定時器、等化器、章節、文字稿、Cast/Auto/Wear）。保留最小可用播放（播放/暫停/跳轉/通知/藍牙焦點）。

---

## 0. 決議摘要（已鎖定）
- **熱門來源策略**：Apple Podcasts（TW 地區排行榜 RSS 作為唯一來源）。
- **雲端同步**：先不做（僅本機）。
- **搜尋來源**：**線上 Apple**（iTunes/Apple Podcasts Search）；不做第三方混搭。*註：本機資料頁面仍可本地篩選，但全域搜尋指向線上 Apple。*
- **智慧下載預設**：Wi‑Fi **+ 最新 2 集**（使用者可在 1–3 集間調整）+ 容量上限 **2GB** 可調。
- **Min SDK**：26；**Target SDK**：最新。
- **分析/崩潰回報**：不蒐集（不接 Crashlytics/Analytics）。
- **UI 主題**：跟隨系統（Light/Dark by System）。

---

## 1. 產品範疇（Scope）

### 1.1 必備功能（In-Scope）
- **探索與發現**
  - 台灣熱門榜單（Apple Podcasts TW 排行）：每日快取、依分類瀏覽。
  - 發現頁：分類/標籤/語言/更新頻率/平均時長等 **篩選/排序**（基於抓到的節目中可用欄位）。
  - 規則式推薦：同分類/上升中/常被一起訂閱（以榜單關聯規則產生，無個人化）。
- **搜尋**
  - 全域搜尋使用 **Apple 線上搜尋**（關鍵字 → 節目/單集結果）。
  - 點擊結果可進入頻道頁或單集頁（若僅回傳節目，單集列表由 RSS 取得）。
- **訂閱與資料管理**
  - 訂閱/退訂、批次管理。
  - OPML 匯入/匯出（跨 App 遷移）。
  - 多播放清單（手動/智慧清單）；智慧清單例：`未播放 且 時長 < 30 分鐘`、`下載完成 且 未完成`。
  - 智慧下載規則（見 4.4）。
  - 下載佇列：排隊、暫停/繼續、失敗重試、前景服務通知。
- **通知與背景作業**
  - 新集數/每日摘要通知、下載完成/失敗通知。
  - 週期性更新排程（WorkManager，依網路/電量條件）。

### 1.2 不在範疇（Out-of-Scope 本期不做）
- 倍速播放、睡眠定時器、靜音跳過、音量增益/等化器。
- 章節顯示與跳轉、文字稿呈現/搜尋。
- Chromecast、Android Auto、Wear OS。
- 雲端登入/跨裝置同步。

---

## 2. 架構與模組

### 2.1 分層
- **Presentation（UI）**：Jetpack Compose + Navigation；ViewModel + StateFlow 管理狀態。
- **Domain**：Use Cases（純 Kotlin）封裝：熱門聚合、去重/排序、下載策略、清理規則、OPML、通知規則。
- **Data**：Repository Pattern；來源：本地 DB（Room/FTS）、網路（Apple Search JSON + RSS）、檔案/下載儲存。
- **Playback（基礎）**：Media3（ExoPlayer）+ MediaSessionService + PlayerNotification（基本控制）。
- **Background**：WorkManager（抓取更新、自動下載、清理、每日通知）。
- **DI**：Hilt；**設定**：DataStore（Preferences/Proto）。

### 2.2 功能模組（多模組建議）
```
:core:ui           // UI 共用元件、樣式、錯誤視圖
:core:design       // 主題、排版
:core:network      // OkHttp/Retrofit、Apple Search、RSS fetch
:core:data         // Repositories、mappers
:core:db           // Room Entities/DAOs（含 FTS）
:core:download     // 下載引擎、Cache 管理
:feature:home      // 熱門/發現頁
:feature:search    // 全域搜尋（Apple 線上）
:feature:podcast   // 頻道頁、訂閱管理
:feature:episode   // 單集頁、下載操作
:feature:playlist  // 播放清單/智慧清單
:feature:settings  // 設定與 OPML 匯入/匯出
:feature:notifications // 通知建立與導流
:feature:player    // 基礎播放器（UI 最小化）
```

---

## 3. 資料流與來源

### 3.1 Apple 熱門榜單（TW）
- **來源**：Apple Podcasts 排行 RSS（國家=TW，可選分類）。
- **流程**：
  1) `ChartsRepository.fetchTrendingTW(category?)` 以網路取得 RSS → 解析 → 轉換為 `Podcast`。
  2) 以 `feedUrl` 去重；以名次作權重，直接依 RSS 排名即可（單一來源）。
  3) 結果快取（Room + 失效時間 24h，可手動刷新）。

### 3.2 Apple 線上搜尋
- **介面**：`SearchRepository.searchRemote(query)` → 呼叫 Apple Search（關鍵字、類型=podcast/podcastEpisode）。
- **合併**：若回傳節目，進入頻道頁時由其 RSS 補齊單集資料；若回傳單集，嘗試以 `feedUrl+guid` 與本機去重。
- **額外考量**：速率限制、語言/地區參數（預設 TW）。

### 3.3 RSS 解析與更新
- 訂閱後將 `feedUrl` 納入更新清單；`RefreshFeedsWorker` 週期抓取。
- 容錯：301/302 追蹤、新舊 GUID 對應、缺欄位容忍（以描述/標題回填）。

---

## 4. 重要規則

### 4.1 去重鍵與主鍵
- 節目以 `feedUrl` 歸一；單集以 `podcastId + guid` 為鍵。

### 4.2 檔案與快取
- 串流使用 Media3 `CacheDataSource`（上限 512MB）。
- 封面圖快取（Disk 64MB）。

### 4.3 下載佇列與重試
- WorkManager 前景任務；重試採指數退避；可暫停/繼續/取消。

### 4.4 智慧下載規則（預設）
- 僅 **Wi‑Fi**；每個訂閱自動下載 **最新 2 集**（使用者可調 1–3）；
- 全域容量上限 **2GB**（可調）；達上限觸發 **LRU + 規則清理**：
  - 已完成且 >N 天未播放優先刪除；
  - 仍保留最近在播與最近下載；
  - 允許清單白名單（不清理）。

### 4.5 通知
- 新集數通知（可批次/每日摘要）；下載完成/失敗通知；點擊導向相應頁面。

---

## 5. 資料模型（精簡）
- `Podcast(id, title, author, imageUrl, feedUrl, language, categories, lastUpdate, description, isSubscribed)`
- `Episode(id, podcastId, guid, title, pubDate, duration, audioUrl, fileSize, description, imageUrl?)`
- `Playlist(id, name, type[manual|smart], rules?)` / `PlaylistItem(playlistId, episodeId, order)`
- `Download(id, episodeId, status[pending|running|paused|completed|failed], bytes, localPath?, createdAt, updatedAt)`
- `PlaybackState(episodeId, positionMs, isCompleted, lastPlayedAt)` *（僅基本）*
- `UserSettings(autoDownloadCount, wifiOnly, maxStorageMB, notifPrefs, ... )`
- `SearchIndex(FTS for Episode fields)` *（僅供本機頁面內搜尋，可選）*

---

## 6. Repository 介面（節選）
```kotlin
interface ChartsRepository {
  suspend fun fetchTrendingTW(category: String?, forceRefresh: Boolean = false): List<Podcast>
}

interface AppleSearchRepository {
  suspend fun searchPodcasts(query: String, limit: Int = 50): List<Podcast>
  suspend fun searchEpisodes(query: String, limit: Int = 50): List<Episode>
}

interface PodcastsRepository {
  suspend fun subscribe(feedUrl: String)
  suspend fun unsubscribe(feedUrl: String)
  fun observeSubscriptions(): Flow<List<Podcast>>
  suspend fun refreshPodcast(feedUrl: String)
}

interface EpisodesRepository {
  fun pagingEpisodes(feedUrl: String): Pager<Int, Episode>
  suspend fun markPlayed(episodeId: String)
}

interface DownloadsRepository {
  fun enqueue(episodeId: String)
  fun pause(id: String)
  fun resume(id: String)
  fun cancel(id: String)
  fun observeQueue(): Flow<List<Download>>
}
```

---

## 7. 專案檔案配置（Monorepo 範例）
```
app/
  build.gradle
  src/main/AndroidManifest.xml
core/
  ui/
  design/
  network/
  data/
  db/
  download/
feature/
  home/
  search/
  podcast/
  episode/
  playlist/
  settings/
  notifications/
  player/
```

---

## 8. 依賴套件（最小集合）
- **播放/媒體**：`androidx.media3:media3-exoplayer`, `media3-session`, `media3-ui`
- **資料**：Room（`room-runtime`, `room-ktx`, `room-compiler` via ksp）
- **設定**：`androidx.datastore:datastore-preferences`
- **分頁**：`androidx.paging:paging-runtime`
- **網路/RSS**：OkHttp + Retrofit（Apple Search JSON）；`rssparser`（或 `kotlinx-serialization-xml`）
- **背景工作**：`androidx.work:work-runtime-ktx`
- **DI**：Hilt（`hilt-android`, compiler）
- **影像**：`io.coil-kt:coil-compose`
- **工具**：kotlinx-serialization、timber、OPML 解析（可自寫）

> 不接入 Crashlytics/Analytics；如需日後調試，僅使用本機 log（Timber）。

---

## 9. API 介接（Apple 專用）
- **熱門榜單（RSS）**：以 TW 地區與分類產生 RSS，解析欄位：`title`, `image`, `feedUrl`（若僅提供 store 連結則需再解析或查表獲得 feedUrl）。
- **搜尋（JSON）**：以 `term`, `country=TW`, `media=podcast` / `entity=podcastEpisode` 查詢；回傳欄位對應 `Podcast`/`Episode`。
- **錯誤處理**：網路失敗 → 快取回退；API 節流 → 退避；欄位缺失 → 容錯映射（必要欄位缺失則隱藏項目）。

---

## 10. 背景工作（WorkManager 任務）
- `RefreshFeedsWorker`：週期抓取訂閱 feed 更新（4–12 小時區間，動態依網路/電量）。
- `AutoDownloadWorker`：依規則自動下載最新 N 集（僅 Wi‑Fi/充電時）。
- `CleanupWorker`：超過容量或時間門檻清理下載與快取。
- `DailyDigestWorker`：彙整今日新增/未聽清單，發送通知（預設 09:00）。

---

## 11. UI 版型（Compose）
- **Home/Discover**：
  - 頂部：TW 熱門分類 Tab；
  - 內容：排行榜卡片（名次、封面、作者、訂閱按鈕）；
  - 篩選/排序：語言、更新頻率、平均時長；
  - 下拉更新、錯誤重試區塊。
- **Search**：
  - 輸入 → 走 Apple 線上搜尋；
  - 結果分區：節目 / 單集；
  - 點擊節目 → 頻道頁（RSS 補齊）；點擊單集 → 單集頁。
- **Podcast Detail**：
  - 訂閱/退訂、最新集列表、下載/加入清單快捷鍵、統計（更新頻率、平均長度）。
- **Episode Detail**：show notes、下載狀態、加入清單按鈕。
- **Library**：訂閱、下載、播放清單三分頁；智慧清單條件編輯器；OPML 匯入/匯出入口。
- **Settings**：下載規則（Wi‑Fi、最新 1–3 集、容量上限）、通知偏好、備份/還原。
- **主題**：跟隨系統；提供切換入口僅作輔助（可選）。

---

## 12. 任務清單（Task To‑Do by 里程碑）

### M0 基礎
- [ ] 建專案、多模組骨架、DI、Navigation、主題（跟隨系統）。
- [ ] Media3 基礎播放 + Notification（基本控制）。
- [ ] Room + DataStore + 基本 Repos；定義 Entities/DAOs。

### M1 熱門與發現（Apple）
- [ ] 串接 Apple TW 排行 RSS；解析 → `Podcast`；房內快取與失效策略。
- [ ] Discover UI：分類 Tab、排序/篩選；下拉刷新。

### M2 搜尋（Apple 線上）
- [ ] Apple Search API 封裝；
- [ ] Search UI：節目/單集分區、空狀態、錯誤處理；
- [ ] 點擊導頁：節目→頻道頁、單集→單集頁。

### M3 訂閱與 OPML
- [ ] 訂閱/退訂流程；RSS 解析與更新；
- [ ] OPML 匯入/匯出；重複去除與錯誤提示。

### M4 下載與智慧規則
- [ ] 下載引擎（WorkManager + 前景通知）。
- [ ] 規則：Wi‑Fi、最新 1–3 集（預設 2）、容量上限 2GB；
- [ ] LRU + 規則清理；下載佇列 UI（排隊/暫停/繼續/取消/重試）。

### M5 通知與排程
- [ ] 新集數通知 & 每日摘要；
- [ ] 週期抓取排程；網路/電量條件；
- [ ] 設定頁控制頻率與時間。

### M6 穩定化
- [ ] 無障礙、i18n（繁中/英文）。
- [ ] 效能與啟動時間、錯誤日誌（僅本機）。

---

## 13. 驗收清單（Acceptance Criteria）
- **熱門/榜單**
  - [ ] TW 熱門列表顯示正確；分類切換、排序生效；每日快取。
  - [ ] 解析容錯：缺欄位不崩潰，需顯示可用資訊。
- **搜尋（Apple 線上）**
  - [ ] 依關鍵字回傳節目/單集；
  - [ ] 點擊節目 → 頻道頁成功載入 RSS 單集；
  - [ ] API 錯誤/節流時有提示與退避，UI 可重試。
- **訂閱與 OPML**
  - [ ] 訂閱/退訂流程正確；訂閱後自動抓取新集數；
  - [ ] OPML 匯入/匯出成功，去重與錯誤提示完整。
- **下載與清理**
  - [ ] 手動/自動下載可運作；Wi‑Fi/容量限制生效；
  - [ ] 下載失敗重試；超容量與到期自動清理；
  - [ ] 白名單清單不被清理（若設置）。
- **播放清單**
  - [ ] 手動清單新增/刪除/排序；
  - [ ] 智慧清單依規則即時生成，與下載/播放狀態連動。
- **通知與背景**
  - [ ] 新集數推播/每日摘要；
  - [ ] 週期更新在指定網路/電量條件執行；
  - [ ] 通知點擊正確導頁。
- **隱私與權限**
  - [ ] 僅請求必要權限（通知、媒體存取如需）；
  - [ ] 不蒐集分析數據；隱私政策明確。

---

## 14. 風險與緩解
- **來源限制/欄位缺失**：若排行榜項目無直接 `feedUrl`，需以查表或額外查詢補齊；提供手動回報通道。
- **API 節流**：加上本地快取、退避、離線模式提示。
- **RSS 不一致**：容錯解析、301/302 追蹤、GUID 變更對應。
- **磁碟壓力**：容量上限、LRU 清理、使用者提示。

---

## 15. 建置與環境
- **Min SDK**：26；**Target SDK**：最新；Kotlin 2.x；JDK 17。
- **BuildConfig**：`COUNTRY=TW`、`APPLE_SEARCH_BASE_URL`、`USER_AGENT`（供網路層設定）。
- **權限**：`POST_NOTIFICATIONS`（Android 13+）、網路、前景服務（下載/媒體播放）。
- **主題**：跟隨系統；支援動態顏色（Material3 可選）。

---

## 16. 待辦與備註
- [ ] Apple 排行 RSS 與 Search 欄位對映表（欄位差異清單）。
- [ ] 若後續要加入雲端同步，預留 `:core:sync` 空模組與 `SyncRepository` 介面；現階段不實作。
- [ ] 之後若需要個人化推薦，可新增輕量本機統計（仍不上傳）。

# Android Podcast App 規劃（探索與發現 + 管理與同步 版）

> 版本：**v1.0** — 依你拍板結果定稿。聚焦「探索與發現」與「管理與同步」。**不含進階播放體驗**（如倍速、睡眠定時器、等化器、章節、文字稿、Cast/Auto/Wear）。保留最小可用播放（播放/暫停/跳轉/通知/藍牙焦點）。

---

## 0. 決議摘要（已鎖定）
- **熱門來源策略**：Apple Podcasts（TW 地區排行榜 RSS 作為唯一來源）。
- **雲端同步**：先不做（僅本機）。
- **搜尋來源**：**線上 Apple**（iTunes/Apple Podcasts Search）；不做第三方混搭。*註：本機資料頁面仍可本地篩選，但全域搜尋指向線上 Apple。*
- **智慧下載預設**：Wi‑Fi **+ 最新 2 集**（使用者可在 1–3 集間調整）+ 容量上限 **2GB** 可調。
- **Min SDK**：26；**Target SDK**：最新。
- **分析/崩潰回報**：不蒐集（不接 Crashlytics/Analytics）。
- **UI 主題**：跟隨系統（Light/Dark by System）。

---

## 1. 產品範疇（Scope）

### 1.1 必備功能（In-Scope）
- **探索與發現**
  - 台灣熱門榜單（Apple Podcasts TW 排行）：每日快取、依分類瀏覽。
  - 發現頁：分類/標籤/語言/更新頻率/平均時長等 **篩選/排序**（基於抓到的節目中可用欄位）。
  - 規則式推薦：同分類/上升中/常被一起訂閱（以榜單關聯規則產生，無個人化）。
- **搜尋**
  - 全域搜尋使用 **Apple 線上搜尋**（關鍵字 → 節目/單集結果）。
  - 點擊結果可進入頻道頁或單集頁（若僅回傳節目，單集列表由 RSS 取得）。
- **訂閱與資料管理**
  - 訂閱/退訂、批次管理。
  - OPML 匯入/匯出（跨 App 遷移）。
  - 多播放清單（手動/智慧清單）；智慧清單例：`未播放 且 時長 < 30 分鐘`、`下載完成 且 未完成`。
  - 智慧下載規則（見 4.4）。
  - 下載佇列：排隊、暫停/繼續、失敗重試、前景服務通知。
- **通知與背景作業**
  - 新集數/每日摘要通知、下載完成/失敗通知。
  - 週期性更新排程（WorkManager，依網路/電量條件）。

### 1.2 不在範疇（Out-of-Scope 本期不做）
- 倍速播放、睡眠定時器、靜音跳過、音量增益/等化器。
- 章節顯示與跳轉、文字稿呈現/搜尋。
- Chromecast、Android Auto、Wear OS。
- 雲端登入/跨裝置同步。

---

## 2. 架構與模組

### 2.1 分層
- **Presentation（UI）**：Jetpack Compose + Navigation；ViewModel + StateFlow 管理狀態。
- **Domain**：Use Cases（純 Kotlin）封裝：熱門聚合、去重/排序、下載策略、清理規則、OPML、通知規則。
- **Data**：Repository Pattern；來源：本地 DB（Room/FTS）、網路（Apple Search JSON + RSS）、檔案/下載儲存。
- **Playback（基礎）**：Media3（ExoPlayer）+ MediaSessionService + PlayerNotification（基本控制）。
- **Background**：WorkManager（抓取更新、自動下載、清理、每日通知）。
- **DI**：Hilt；**設定**：DataStore（Preferences/Proto）。

### 2.2 功能模組（多模組建議）
```
:core:ui           // UI 共用元件、樣式、錯誤視圖
:core:design       // 主題、排版
:core:network      // OkHttp/Retrofit、Apple Search、RSS fetch
:core:data         // Repositories、mappers
:core:db           // Room Entities/DAOs（含 FTS）
:core:download     // 下載引擎、Cache 管理
:feature:home      // 熱門/發現頁
:feature:search    // 全域搜尋（Apple 線上）
:feature:podcast   // 頻道頁、訂閱管理
:feature:episode   // 單集頁、下載操作
:feature:playlist  // 播放清單/智慧清單
:feature:settings  // 設定與 OPML 匯入/匯出
:feature:notifications // 通知建立與導流
:feature:player    // 基礎播放器（UI 最小化）
```

---

## 3. 資料流與來源

### 3.1 Apple 熱門榜單（TW）
- **來源**：Apple Podcasts 排行 RSS（國家=TW，可選分類）。
- **流程**：
  1) `ChartsRepository.fetchTrendingTW(category?)` 以網路取得 RSS → 解析 → 轉換為 `Podcast`。
  2) 以 `feedUrl` 去重；以名次作權重，直接依 RSS 排名即可（單一來源）。
  3) 結果快取（Room + 失效時間 24h，可手動刷新）。

### 3.2 Apple 線上搜尋
- **介面**：`SearchRepository.searchRemote(query)` → 呼叫 Apple Search（關鍵字、類型=podcast/podcastEpisode）。
- **合併**：若回傳節目，進入頻道頁時由其 RSS 補齊單集資料；若回傳單集，嘗試以 `feedUrl+guid` 與本機去重。
- **額外考量**：速率限制、語言/地區參數（預設 TW）。

### 3.3 RSS 解析與更新
- 訂閱後將 `feedUrl` 納入更新清單；`RefreshFeedsWorker` 週期抓取。
- 容錯：301/302 追蹤、新舊 GUID 對應、缺欄位容忍（以描述/標題回填）。

---

## 4. 重要規則

### 4.1 去重鍵與主鍵
- 節目以 `feedUrl` 歸一；單集以 `podcastId + guid` 為鍵。

### 4.2 檔案與快取
- 串流使用 Media3 `CacheDataSource`（上限 512MB）。
- 封面圖快取（Disk 64MB）。

### 4.3 下載佇列與重試
- WorkManager 前景任務；重試採指數退避；可暫停/繼續/取消。

### 4.4 智慧下載規則（預設）
- 僅 **Wi‑Fi**；每個訂閱自動下載 **最新 2 集**（使用者可調 1–3）；
- 全域容量上限 **2GB**（可調）；達上限觸發 **LRU + 規則清理**：
  - 已完成且 >N 天未播放優先刪除；
  - 仍保留最近在播與最近下載；
  - 允許清單白名單（不清理）。

### 4.5 通知
- 新集數通知（可批次/每日摘要）；下載完成/失敗通知；點擊導向相應頁面。

---

## 5. 資料模型（精簡）
- `Podcast(id, title, author, imageUrl, feedUrl, language, categories, lastUpdate, description, isSubscribed)`
- `Episode(id, podcastId, guid, title, pubDate, duration, audioUrl, fileSize, description, imageUrl?)`
- `Playlist(id, name, type[manual|smart], rules?)` / `PlaylistItem(playlistId, episodeId, order)`
- `Download(id, episodeId, status[pending|running|paused|completed|failed], bytes, localPath?, createdAt, updatedAt)`
- `PlaybackState(episodeId, positionMs, isCompleted, lastPlayedAt)` *（僅基本）*
- `UserSettings(autoDownloadCount, wifiOnly, maxStorageMB, notifPrefs, ... )`
- `SearchIndex(FTS for Episode fields)` *（僅供本機頁面內搜尋，可選）*

---

## 6. Repository 介面（節選）
```kotlin
interface ChartsRepository {
  suspend fun fetchTrendingTW(category: String?, forceRefresh: Boolean = false): List<Podcast>
}

interface AppleSearchRepository {
  suspend fun searchPodcasts(query: String, limit: Int = 50): List<Podcast>
  suspend fun searchEpisodes(query: String, limit: Int = 50): List<Episode>
}

interface PodcastsRepository {
  suspend fun subscribe(feedUrl: String)
  suspend fun unsubscribe(feedUrl: String)
  fun observeSubscriptions(): Flow<List<Podcast>>
  suspend fun refreshPodcast(feedUrl: String)
}

interface EpisodesRepository {
  fun pagingEpisodes(feedUrl: String): Pager<Int, Episode>
  suspend fun markPlayed(episodeId: String)
}

interface DownloadsRepository {
  fun enqueue(episodeId: String)
  fun pause(id: String)
  fun resume(id: String)
  fun cancel(id: String)
  fun observeQueue(): Flow<List<Download>>
}
```

---

## 7. 專案檔案配置（Monorepo 範例）
```
app/
  build.gradle
  src/main/AndroidManifest.xml
core/
  ui/
  design/
  network/
  data/
  db/
  download/
feature/
  home/
  search/
  podcast/
  episode/
  playlist/
  settings/
  notifications/
  player/
```

---

## 8. 依賴套件（最小集合）
- **播放/媒體**：`androidx.media3:media3-exoplayer`, `media3-session`, `media3-ui`
- **資料**：Room（`room-runtime`, `room-ktx`, `room-compiler` via ksp）
- **設定**：`androidx.datastore:datastore-preferences`
- **分頁**：`androidx.paging:paging-runtime`
- **網路/RSS**：OkHttp + Retrofit（Apple Search JSON）；`rssparser`（或 `kotlinx-serialization-xml`）
- **背景工作**：`androidx.work:work-runtime-ktx`
- **DI**：Hilt（`hilt-android`, compiler）
- **影像**：`io.coil-kt:coil-compose`
- **工具**：kotlinx-serialization、timber、OPML 解析（可自寫）

> 不接入 Crashlytics/Analytics；如需日後調試，僅使用本機 log（Timber）。

---

## 9. API 介接（Apple 專用）
- **熱門榜單（RSS）**：以 TW 地區與分類產生 RSS，解析欄位：`title`, `image`, `feedUrl`（若僅提供 store 連結則需再解析或查表獲得 feedUrl）。
- **搜尋（JSON）**：以 `term`, `country=TW`, `media=podcast` / `entity=podcastEpisode` 查詢；回傳欄位對應 `Podcast`/`Episode`。
- **錯誤處理**：網路失敗 → 快取回退；API 節流 → 退避；欄位缺失 → 容錯映射（必要欄位缺失則隱藏項目）。

---

## 10. 背景工作（WorkManager 任務）
- `RefreshFeedsWorker`：週期抓取訂閱 feed 更新（4–12 小時區間，動態依網路/電量）。
- `AutoDownloadWorker`：依規則自動下載最新 N 集（僅 Wi‑Fi/充電時）。
- `CleanupWorker`：超過容量或時間門檻清理下載與快取。
- `DailyDigestWorker`：彙整今日新增/未聽清單，發送通知（預設 09:00）。

---

## 11. UI 版型（Compose）
- **Home/Discover**：
  - 頂部：TW 熱門分類 Tab；
  - 內容：排行榜卡片（名次、封面、作者、訂閱按鈕）；
  - 篩選/排序：語言、更新頻率、平均時長；
  - 下拉更新、錯誤重試區塊。
- **Search**：
  - 輸入 → 走 Apple 線上搜尋；
  - 結果分區：節目 / 單集；
  - 點擊節目 → 頻道頁（RSS 補齊）；點擊單集 → 單集頁。
- **Podcast Detail**：
  - 訂閱/退訂、最新集列表、下載/加入清單快捷鍵、統計（更新頻率、平均長度）。
- **Episode Detail**：show notes、下載狀態、加入清單按鈕。
- **Library**：訂閱、下載、播放清單三分頁；智慧清單條件編輯器；OPML 匯入/匯出入口。
- **Settings**：下載規則（Wi‑Fi、最新 1–3 集、容量上限）、通知偏好、備份/還原。
- **主題**：跟隨系統；提供切換入口僅作輔助（可選）。

---

## 12. 任務清單（Task To‑Do by 里程碑）

### M0 基礎
- [ ] 建專案、多模組骨架、DI、Navigation、主題（跟隨系統）。
- [ ] Media3 基礎播放 + Notification（基本控制）。
- [ ] Room + DataStore + 基本 Repos；定義 Entities/DAOs。

### M1 熱門與發現（Apple）
- [ ] 串接 Apple TW 排行 RSS；解析 → `Podcast`；房內快取與失效策略。
- [ ] Discover UI：分類 Tab、排序/篩選；下拉刷新。

### M2 搜尋（Apple 線上）
- [ ] Apple Search API 封裝；
- [ ] Search UI：節目/單集分區、空狀態、錯誤處理；
- [ ] 點擊導頁：節目→頻道頁、單集→單集頁。

### M3 訂閱與 OPML
- [ ] 訂閱/退訂流程；RSS 解析與更新；
- [ ] OPML 匯入/匯出；重複去除與錯誤提示。

### M4 下載與智慧規則
- [ ] 下載引擎（WorkManager + 前景通知）。
- [ ] 規則：Wi‑Fi、最新 1–3 集（預設 2）、容量上限 2GB；
- [ ] LRU + 規則清理；下載佇列 UI（排隊/暫停/繼續/取消/重試）。

### M5 通知與排程
- [ ] 新集數通知 & 每日摘要；
- [ ] 週期抓取排程；網路/電量條件；
- [ ] 設定頁控制頻率與時間。

### M6 穩定化
- [ ] 無障礙、i18n（繁中/英文）。
- [ ] 效能與啟動時間、錯誤日誌（僅本機）。

---

## 13. 驗收清單（Acceptance Criteria）
- **熱門/榜單**
  - [ ] TW 熱門列表顯示正確；分類切換、排序生效；每日快取。
  - [ ] 解析容錯：缺欄位不崩潰，需顯示可用資訊。
- **搜尋（Apple 線上）**
  - [ ] 依關鍵字回傳節目/單集；
  - [ ] 點擊節目 → 頻道頁成功載入 RSS 單集；
  - [ ] API 錯誤/節流時有提示與退避，UI 可重試。
- **訂閱與 OPML**
  - [ ] 訂閱/退訂流程正確；訂閱後自動抓取新集數；
  - [ ] OPML 匯入/匯出成功，去重與錯誤提示完整。
- **下載與清理**
  - [ ] 手動/自動下載可運作；Wi‑Fi/容量限制生效；
  - [ ] 下載失敗重試；超容量與到期自動清理；
  - [ ] 白名單清單不被清理（若設置）。
- **播放清單**
  - [ ] 手動清單新增/刪除/排序；
  - [ ] 智慧清單依規則即時生成，與下載/播放狀態連動。
- **通知與背景**
  - [ ] 新集數推播/每日摘要；
  - [ ] 週期更新在指定網路/電量條件執行；
  - [ ] 通知點擊正確導頁。
- **隱私與權限**
  - [ ] 僅請求必要權限（通知、媒體存取如需）；
  - [ ] 不蒐集分析數據；隱私政策明確。

---

## 14. 風險與緩解
- **來源限制/欄位缺失**：若排行榜項目無直接 `feedUrl`，需以查表或額外查詢補齊；提供手動回報通道。
- **API 節流**：加上本地快取、退避、離線模式提示。
- **RSS 不一致**：容錯解析、301/302 追蹤、GUID 變更對應。
- **磁碟壓力**：容量上限、LRU 清理、使用者提示。

---

## 15. 建置與環境
- **Min SDK**：26；**Target SDK**：最新；Kotlin 2.x；JDK 17。
- **BuildConfig**：`COUNTRY=TW`、`APPLE_SEARCH_BASE_URL`、`USER_AGENT`（供網路層設定）。
- **權限**：`POST_NOTIFICATIONS`（Android 13+）、網路、前景服務（下載/媒體播放）。
- **主題**：跟隨系統；支援動態顏色（Material3 可選）。

---

## 16. 待辦與備註
- [ ] Apple 排行 RSS 與 Search 欄位對映表（欄位差異清單）。
- [ ] 若後續要加入雲端同步，預留 `:core:sync` 空模組與 `SyncRepository` 介面；現階段不實作。
- [ ] 之後若需要個人化推薦，可新增輕量本機統計（仍不上傳）。

