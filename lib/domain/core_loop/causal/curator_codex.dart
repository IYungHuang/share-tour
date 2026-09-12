/// 策展手冊詞條不可變實體
class CodexEntry {
  final String title;
  final String jargon;
  final String explanation;
  final String guideNote;

  const CodexEntry({
    required this.title,
    required this.jargon,
    required this.explanation,
    required this.guideNote,
  });
}

/// 策展因果規則手冊（純領域常數字典，零依賴，不含具名城市）
class CuratorCodex {
  static const Map<String, CodexEntry> entries = {
    'fatigue_spike': CodexEntry(
      title: '拉車疲勞',
      jargon: '遊覽車睡死',
      explanation: '連續安排高耗能行程，旅客體力透支、怨聲載道。',
      guideNote: '阿導筆記：兩段硬行程中間，墊一張悠閒的。',
    ),
    'fatigue_hype_penalty': CodexEntry(
      title: '脫妝暴跌',
      jargon: '網美翻車',
      explanation: '高強度奔波讓網紅脫妝狼狽，打卡熱度大幅折損。',
      guideNote: '阿導筆記：拍美照要優雅，別讓網紅跑馬拉松。',
    ),
    'chaotic_combo': CodexEntry(
      title: '驚險連段',
      jargon: '極限特技',
      explanation: '在追求刺激的冒險哲學下，連續高壓行程轉化為爆炸性話題。',
      guideNote: '阿導筆記：心跳加速就是流量密碼，越瘋越有人看！',
    ),
    'rhythm_complement': CodexEntry(
      title: '節奏互補',
      jargon: '一張一弛',
      explanation: '高低風險行程相間排列，動靜得宜讓旅程豐富且舒適。',
      guideNote: '阿導筆記：緊湊之後來點漫步，旅客心情自然好。',
    ),
    'philosophy_repelled': CodexEntry(
      title: '哲學排斥',
      jargon: '踩到地雷',
      explanation: '景點帶有旅客極度排斥的屬性，大幅破壞主題沉浸感。',
      guideNote: '阿導筆記：出發前務必看清哲學禁忌，千萬別硬塞。',
    ),
    'philosophy_matched_major': CodexEntry(
      title: '強烈共鳴',
      jargon: '靈魂知音',
      explanation: '素材完美契合多項核心偏好，旅客讚不絕口。',
      guideNote: '阿導筆記：精準命中核心喜好，是拿下滿分的捷徑。',
    ),
    'philosophy_matched_minor': CodexEntry(
      title: '哲學契合',
      jargon: '投其所好',
      explanation: '景點符合旅客的旅行哲學，穩定貢獻主題期待。',
      guideNote: '阿導筆記：積少成多，確保整體行程方向不走偏。',
    ),
    'budget_overrun_minor': CodexEntry(
      title: '超支·輕度',
      jargon: '稍微爆單',
      explanation: '總開銷略微超出客戶預算上限，扣減少量預算分數。',
      guideNote: '阿導筆記：稍微擠一擠還能接受，但別再往上加了。',
    ),
    'budget_overrun_major': CodexEntry(
      title: '超支·爆表',
      jargon: '破產慘劇',
      explanation: '開銷嚴重超標逾 15%，預算分數將面臨斷崖式崩跌。',
      guideNote: '阿導筆記：社畜的荷包在淌血！立刻換掉昂貴景點。',
    ),
    'spotlight_shortfall': CodexEntry(
      title: '絕景缺口',
      jargon: '缺少大景',
      explanation: '行程缺乏焦點絕景素材，網紅客戶的吸睛成效將大幅打折。',
      guideNote: '阿導筆記：沒有招牌大景怎麼發貼文？快排入絕景卡。',
    ),
    'spotlight_full': CodexEntry(
      title: '絕景大滿貫',
      jargon: '流量巔峰',
      explanation: '排滿 4 張焦點絕景達成大滿貫，熱度乘數完全解放至 100%。',
      guideNote: '阿導筆記：滿版無死角神級排程，引爆社交圈熱搜！',
    ),
    'boredom_risk': CodexEntry(
      title: '乏味風險',
      jargon: '坐牢行程',
      explanation: '行程總熱度低於反無聊門檻，社畜客戶將直接扣除 25 分。',
      guideNote: '阿導筆記：省錢也不能像坐牢，至少加個熱門景點提神。',
    ),
    'tag_synergy': CodexEntry(
      title: '同標籤共鳴',
      jargon: '連鎖效應',
      explanation: '相鄰槽位素材帶有共同標籤，前後呼應激發熱度加成。',
      guideNote: '阿導筆記：把同類型的景點排在一起，能創造連續話題。',
    ),
    'ambient_slot_affinity': CodexEntry(
      title: '時段契合',
      jargon: '天時地利',
      explanation: '在恰當的時間走訪恰當的景點，享受時段專屬氛圍加分。',
      guideNote: '阿導筆記：晨曦散步、午後美食、深夜小酌，順應天時。',
    ),
  };

  /// 依 reasonCode 查詢對應策展手冊詞條
  static CodexEntry? lookup(String reasonCode) => entries[reasonCode];
}
