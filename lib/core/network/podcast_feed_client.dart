/// 這個檔案負責：
/// - 透過 HTTP 抓取 Podcast 的 RSS/Atom Feed
/// - 解析節目清單（episodes），並產出乾淨的資料模型
/// - 處理常見的 RSS 命名空間（itunes、media）、日期格式、音訊連結萃取
///
/// 輸入：feed 的 URL 字串
/// 輸出：解析後的 `List<Episode>`
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../data/models/podcast.dart' as models show Episode;
import 'http_client_provider.dart';

final podcastFeedClientProvider = Provider<PodcastFeedClient>((ref) {
  final client = ref.watch(httpClientProvider);
  return PodcastFeedClient(httpClient: client);
}, name: 'podcastFeedClientProvider');

class PodcastFeedClient {
  /// 以注入的 `httpClient` 建立 RSS/Atom 解析客戶端
  /// 輸入：`httpClient`
  /// 輸出：`PodcastFeedClient` 實例
  PodcastFeedClient({required this.httpClient});

  final http.Client httpClient;

  /// 依據 feedUrl 下載並解析節目清單
  /// 輸入：feedUrl（字串）
  /// 輸出：`List<Episode>`，若 HTTP 非 200 會丟出例外
  Future<List<models.Episode>> fetchEpisodes(String feedUrl) async {
    final response = await httpClient.get(
      Uri.parse(feedUrl),
      headers: {
        'Accept': 'application/xml',
        'Accept-Charset': 'utf-8',
        'User-Agent': 'PodcastPlayer/1.0 (Flutter)',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('無法載入 feed：${response.reasonPhrase}');
    }

    // 確保以 UTF-8 解碼回應
    final responseBody = utf8.decode(response.bodyBytes);
    return _parseFeed(responseBody);
  }

  /// 解析 XML 字串成 `Episode` 清單
  /// - 支援 RSS `<item>`；若為 Atom 則嘗試 `<entry>`（僅作保守回退）
  /// - 僅接受具有有效音訊 URL 的項目
  List<models.Episode> _parseFeed(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    List<XmlElement> items =
        document.findAllElements('item').toList(growable: false);

    // 若沒有 RSS item，嘗試 Atom entry（部分來源會這樣）
    if (items.isEmpty) {
      items = document.findAllElements('entry').toList(growable: false);
    }

    return items
        .map(_mapItemToEpisode)
        .whereType<models.Episode>()
        .toList(growable: false);
  }

  /// 將單一 `<item>`/`<entry>` 節點映射為 `Episode`
  /// 規則：
  /// - 需有 `title`
  /// - 需可抽出有效音訊網址（優先 enclosure/media:content，不再盲用 link）
  /// - id 優先使用 guid，否則退回音訊網址
  models.Episode? _mapItemToEpisode(XmlElement item) {
    final titleText = _firstText(item, ['title']);
    if (titleText == null || titleText.isEmpty) return null;

    // 音訊 URL：優先 enclosure / media:content；避免盲用 link（多半是網頁而非音訊）
    final audioUrl = _extractAudioUrl(item);
    if (audioUrl == null || audioUrl.isEmpty) return null;

    // guid 作為穩定 id，缺少時以音訊 URL 作為替代
    final guid = _firstText(item, ['guid']);
    final id = (guid?.trim().isNotEmpty == true) ? guid!.trim() : audioUrl;

    // 敘述：先 description，其次 content:encoded（常見於部落格型 feed）
    final description = _firstText(
      item,
      ['description', 'content:encoded'],
    )?.trim();

    // 發佈時間：RSS pubDate（RFC822 為主），失敗時回傳 null
    final pubDateText = _firstText(item, ['pubDate', 'published']);
    final publishedAt = _tryParseRssDate(pubDateText);

    // 時長：支援 itunes:duration（hh:mm:ss 或總秒數）
    final durationText = _firstText(item, ['itunes:duration']);
    final duration = durationText != null ? _tryParseDuration(durationText) : null;

    // 影像：優先 itunes:image@href；退而求其次 media:thumbnail/media:content
    final imageUrl = _extractImageUrl(item);

    return models.Episode(
      id: id,
      title: titleText.trim(),
      audioUrl: audioUrl,
      description: description,
      publishedAt: publishedAt,
      duration: duration,
      imageUrl: imageUrl,
    );
  }

  /// 嘗試解析時長，支援：
  /// - hh:mm:ss
  /// - mm:ss
  /// - 純秒數（字串數字）
  /// 失敗回傳 null
  Duration? _tryParseDuration(String input) {
    final parts = input.split(':');
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      final seconds = int.tryParse(parts[2]);
      if (hours != null && minutes != null && seconds != null) {
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    } else if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      final seconds = int.tryParse(parts[1]);
      if (minutes != null && seconds != null) {
        return Duration(minutes: minutes, seconds: seconds);
      }
    }

    final totalSeconds = int.tryParse(input.trim());
    if (totalSeconds != null) {
      return Duration(seconds: totalSeconds);
    }

    return null;
  }

  /// 嘗試以常見 RSS/Atom 格式解析日期
  /// 支援範例：
  /// - Mon, 09 Sep 2024 16:00:00 +0000
  /// - Mon, 09 Sep 2024 16:00:00 GMT
  /// - 09 Sep 2024 16:00:00 +0800
  /// - 2024-09-09T16:00:00Z（ISO 8601，交給 DateTime.tryParse）
  DateTime? _tryParseRssDate(String? input) {
    if (input == null) return null;
    final text = input.trim();
    // 先試 ISO 8601
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso.toUtc();

    // RFC822/1123/常見變體簡易解析
    final regex = RegExp(
      r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s+([A-Za-z]{3}|[+-]\d{4})$',
    );
    final m = regex.firstMatch(text);
    if (m == null) return null;

    final day = int.tryParse(m.group(1)!);
    final monStr = m.group(2)!.toLowerCase();
    final year = int.tryParse(m.group(3)!);
    final hour = int.tryParse(m.group(4)!);
    final minute = int.tryParse(m.group(5)!);
    final second = int.tryParse(m.group(6) ?? '0');
    final tz = m.group(7)!;

    if ([day, year, hour, minute, second].any((e) => e == null)) return null;

    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final month = months[monStr];
    if (month == null) return null;

    // 建立 UTC 時間，再依時區位移修正
    var dt = DateTime.utc(year!, month, day!, hour!, minute!, second!);

    // 時區：支援 +0800 / -0500 / GMT / UTC
    if (tz.toUpperCase() == 'GMT' || tz.toUpperCase() == 'UTC') {
      return dt;
    }
    final off = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(tz);
    if (off != null) {
      final sign = off.group(1) == '-' ? -1 : 1;
      final h = int.tryParse(off.group(2)!);
      final m = int.tryParse(off.group(3)!);
      if (h != null && m != null) {
        final total = Duration(hours: h, minutes: m) * sign;
        // 文字時間為「當地時間」，轉成 UTC 需減去位移
        dt = dt.subtract(total);
      }
    }
    return dt;
  }

  /// 取得元素文字（支援多個候選名稱與命名空間前綴）
  /// 例如：['description', 'content:encoded']
  String? _firstText(XmlElement scope, List<String> names) {
    for (final name in names) {
      final el = _firstElement(scope, name);
      if (el != null) {
        final text = el.innerText;
        if (text.trim().isNotEmpty) return text;
      }
    }
    return null;
  }

  /// 在節點底下尋找第一個符合名稱的元素
  /// - 支援 `prefix:local`（如 itunes:duration）
  /// - 若無冒號即用原生名搜尋
  XmlElement? _firstElement(XmlElement scope, String name) {
    if (name.contains(':')) {
      final parts = name.split(':');
      final local = parts.last.toLowerCase();
      for (final el in scope.descendants.whereType<XmlElement>()) {
        if (el.name.local.toLowerCase() == local) return el;
      }
      return null;
    } else {
      final direct = scope.getElement(name);
      if (direct != null) return direct;
      for (final el in scope.findElements(name)) {
        return el;
      }
      return null;
    }
  }

  /// 擷取音訊連結：
  /// - <enclosure url="..." type="audio/*"> 優先
  /// - <media:content url="..." type="audio/*">
  /// - 若無，最後才嘗試 <link> 但需副檔名判斷為音訊
  String? _extractAudioUrl(XmlElement item) {
    // enclosure
    for (final enc in item.findElements('enclosure')) {
      final url = enc.getAttribute('url')?.trim();
      final type = (enc.getAttribute('type') ?? '').toLowerCase();
      if (url != null && url.isNotEmpty) {
        if (type.startsWith('audio/') || _looksLikeAudioUrl(url)) return url;
      }
    }

    // media:content（prefix 可能不同，改以 localName 比對）
    for (final el in item.descendants.whereType<XmlElement>()) {
      if (el.name.local.toLowerCase() == 'content') {
        final url = el.getAttribute('url')?.trim();
        final type = (el.getAttribute('type') ?? '').toLowerCase();
        if (url != null && url.isNotEmpty) {
          if (type.startsWith('audio/') || _looksLikeAudioUrl(url)) return url;
        }
      }
    }

    // link（僅當看起來像音訊檔才接受）
    final linkText = _firstText(item, ['link']);
    if (linkText != null && _looksLikeAudioUrl(linkText)) {
      return linkText;
    }

    return null;
  }

  /// 粗略判斷 URL 是否為音訊檔案
  bool _looksLikeAudioUrl(String url) {
    final u = url.toLowerCase();
    return u.endsWith('.mp3') ||
        u.endsWith('.m4a') ||
        u.endsWith('.aac') ||
        u.endsWith('.ogg') ||
        u.endsWith('.opus');
  }

  /// 擷取影像：
  /// - itunes:image@href 優先
  /// - media:thumbnail@url / media:content@url 次之
  String? _extractImageUrl(XmlElement item) {
    final itunesImage = _firstElement(item, 'itunes:image')?.getAttribute('href');
    if (itunesImage != null && itunesImage.trim().isNotEmpty) {
      return itunesImage.trim();
    }

    for (final el in item.descendants.whereType<XmlElement>()) {
      final local = el.name.local.toLowerCase();
      if (local == 'thumbnail' || local == 'content' || local == 'image') {
        final url = el.getAttribute('url') ?? el.getAttribute('href');
        if (url != null && url.trim().isNotEmpty) {
          return url.trim();
        }
      }
    }
    return null;
  }
}
