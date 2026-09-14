import 'package:share_tour/domain/core_loop/models/travel_material.dart';

/// 京都夜間 32 處精選旅行素材資料庫 (City as DLC Seed Data)
///
/// 涵蓋五大旅行哲學偏好標籤：
/// - `#深夜` (夜行獵手)
/// - `#老街` (散步慢遊)
/// - `#美食` (極致老饕)
/// - `#巷弄秘境` (反觀光客)
/// - `#高風險` (混亂探險)
///
/// 以及拉車標籤 `#拉車` 與焦點絕景 `isSpotlight: true`。
const List<TravelMaterial> kyotoNightMaterials = [
  // 1. 先斗町迷路三花貓
  TravelMaterial(
    id: 'kyoto_pontocho_cat',
    name: '先斗町迷路三花貓',
    tags: ['#深夜', '#巷弄秘境', '#散步'],
    themeValue: 25,
    hypeValue: 35,
    storyValue: 4,
    cost: 0,
    riskLevel: 1,
    description: '在狹窄的石板小巷偶遇穿梭木造長屋的野貓，跟著牠走到未知的私宅後院。',
    perfectDescription: '在狹窄的石板小巷偶遇穿梭木造長屋的野貓，快門定格的瞬間，牠正回頭瞥了你一眼，尾巴甩成一個問號。',
  ),

  // 2. 01:00 幽靈自販機
  TravelMaterial(
    id: 'kyoto_ghost_vending',
    name: '01:00 幽靈自販機',
    tags: ['#深夜', '#怪談', '#銅板美食'],
    themeValue: 30,
    hypeValue: 40,
    storyValue: 3,
    cost: 150,
    riskLevel: 2,
    description: '坐落於昏暗街角的復古自販機，在深夜會吐出早已停產的復古玻璃瓶咖啡。',
    perfectDescription: '坐落於昏暗街角的復古自販機，快門按下時投幣口正好吐出一枚泛黃的舊硬幣，跟咖啡一起掉出來。',
  ),

  // 3. 祇園白川辰巳大明神夜櫻 (Spotlight)
  TravelMaterial(
    id: 'kyoto_gion_tatsumi',
    name: '祇園白川辰巳大明神夜櫻',
    tags: ['#老街', '#古蹟', '#絕景'],
    themeValue: 35,
    hypeValue: 60,
    isSpotlight: true,
    storyValue: 4,
    cost: 0,
    riskLevel: 1,
    description: '白川潺潺流水與朱紅小橋映照垂櫻，藝妓足音在石板路上迴盪。',
    perfectDescription: '白川潺潺流水與朱紅小橋映照垂櫻，快門落下那一瞬，一片花瓣正好停在水面上還沒被沖走。',
    failedDescription: '白川潺潺流水與朱紅小橋映照垂櫻，畫面正中央是一位舉著自拍棒、對你比讚的觀光客。',
  ),

  // 4. 伏見稻荷千本鳥居深夜陰影 (Spotlight)
  TravelMaterial(
    id: 'kyoto_fushimi_torii',
    name: '伏見稻荷千本鳥居深夜陰影',
    tags: ['#深夜', '#怪談', '#高風險', '#絕景'],
    themeValue: 45,
    hypeValue: 75,
    isSpotlight: true,
    storyValue: 5,
    cost: 0,
    riskLevel: 4,
    description: '午夜無人的朱紅鳥居長廊，狐狸石像在林木陰影中默默注視著每位夜行者。',
    perfectDescription: '午夜無人的朱紅鳥居長廊，快門捕捉到山風正巧掀起鳥居懸掛的白色紙垂，像是狐狸石像對你眨了眼。',
    failedDescription: '午夜無人的朱紅鳥居長廊，一隻受驚的野貓竄過鏡頭前糊成一道白色殘影，狐狸石像倒是拍得很清楚。',
  ),

  // 5. 鴨川三角洲深夜發呆等日出
  TravelMaterial(
    id: 'kyoto_kamogawa_delta',
    name: '鴨川三角洲深夜發呆等日出',
    tags: ['#深夜', '#散步', '#浪漫'],
    themeValue: 20,
    hypeValue: 25,
    storyValue: 2,
    cost: 0,
    riskLevel: 1,
    description: '坐在出町柳烏龜跳石上聽著夜間水流，等待東山山頭染上淡藍晨光。',
    perfectDescription: '坐在出町柳烏龜跳石上聽著夜間水流，快門落下的剎那，一隻白鷺正好掠過水面激起細碎波紋。',
  ),

  // 6. 八坂之塔清晨藍調時刻 (Spotlight)
  TravelMaterial(
    id: 'kyoto_yasaka_pagoda',
    name: '八坂之塔清晨藍調時刻',
    tags: ['#老街', '#絕景', '#早餐'],
    themeValue: 40,
    hypeValue: 70,
    isSpotlight: true,
    storyValue: 4,
    cost: 500,
    riskLevel: 2,
    description: '日出前三十分鐘的法觀寺五重塔，石坡空無一人，晨曦如水洗般純淨。',
    perfectDescription: '日出前三十分鐘的法觀寺五重塔，快門按下時第一道陽光正好斜切過塔頂，把石坡染成一片金粉色。',
    failedDescription: '日出前三十分鐘的法觀寺五重塔，一輛送報機車轟隆騎過石坡，車燈晃進畫面把塔身照得慘白。',
  ),

  // 7. 木屋町通深夜醉漢背脂拉麵
  TravelMaterial(
    id: 'kyoto_kiyamachi_ramen',
    name: '木屋町通深夜醉漢背脂拉麵',
    tags: ['#深夜', '#美食', '#銅板美食'],
    themeValue: 20,
    hypeValue: 30,
    storyValue: 2,
    cost: 850,
    riskLevel: 2,
    description: '清晨兩點依然沸騰的濃郁醬油豚骨高湯，滿滿蔥花治癒了長夜的疲憊。',
    perfectDescription: '清晨兩點依然沸騰的濃郁醬油豚骨高湯，快門定格住那縷剛好升起的白色蒸氣，蔥花還在湯面上打轉。',
  ),

  // 8. 伏見清酒老窖無過濾生原酒
  TravelMaterial(
    id: 'kyoto_shinsei_sake',
    name: '伏見清酒老窖無過濾生原酒',
    tags: ['#美食', '#小酌', '#老街'],
    themeValue: 35,
    hypeValue: 35,
    storyValue: 4,
    cost: 1200,
    riskLevel: 1,
    description: '伏見名水釀造的在地生原酒，微氣泡感與米香在舌尖緩緩爆發。',
    perfectDescription: '伏見名水釀造的在地生原酒，快門捕捉到倒酒瞬間杯緣正好凝出一圈細緻的白色氣泡。',
  ),

  // 9. 鞍馬夜行末班單節電車
  TravelMaterial(
    id: 'kyoto_kurama_night_train',
    name: '鞍馬夜行末班單節電車',
    tags: ['#拉車', '#巷弄秘境', '#高風險'],
    themeValue: 30,
    hypeValue: 45,
    storyValue: 5,
    cost: 450,
    riskLevel: 3,
    description: '穿行於漆黑杉木林間的叡山電鐵，車廂內只有規律的金屬軌道摩擦聲。',
    perfectDescription: '穿行於漆黑杉木林間的叡山電鐵，快門按下那刻車窗外正好掠過一整片被月光鍍銀的杉樹林。',
  ),

  // 10. 嵐山竹林小徑午夜風嘯
  TravelMaterial(
    id: 'kyoto_arashiyama_bamboo',
    name: '嵐山竹林小徑午夜風嘯',
    tags: ['#深夜', '#怪談', '#拉車', '#高風險'],
    themeValue: 35,
    hypeValue: 50,
    storyValue: 4,
    cost: 300,
    riskLevel: 4,
    description: '白日喧鬧的竹林深處，午夜只有狂風穿透青竹的尖嘯與婆娑竹影。',
    perfectDescription: '白日喧鬧的竹林深處，快門落下瞬間一陣強風正好把整片竹梢壓成同一個弧度，宛如綠色浪潮。',
  ),

  // 11. 知恩院三門前巨大石階冥想
  TravelMaterial(
    id: 'kyoto_chionin_stairs',
    name: '知恩院三門前巨大石階冥想',
    tags: ['#老街', '#散步', '#古蹟'],
    themeValue: 25,
    hypeValue: 20,
    storyValue: 3,
    cost: 0,
    riskLevel: 1,
    description: '坐在全日本最大的木造山門石階上，遠眺京都市街的昏黃燈海。',
    perfectDescription: '坐在全日本最大的木造山門石階上，快門定格時街燈正好熄滅又亮起，像對你眨眼。',
  ),

  // 12. 熄燈後的錦市場百鬼卷軸
  TravelMaterial(
    id: 'kyoto_nishiki_closed',
    name: '熄燈後的錦市場百鬼卷軸',
    tags: ['#深夜', '#老街', '#巷弄秘境'],
    themeValue: 30,
    hypeValue: 30,
    storyValue: 3,
    cost: 0,
    riskLevel: 1,
    description: '店家拉下鐵捲門後，伊藤若沖筆下的鳥獸草木浮世繪在夜色中甦醒。',
    perfectDescription: '店家拉下鐵捲門後，快門按下那刻一陣穿堂風正好吹得卷軸畫的邊角微微掀起，像鳥獸真的要飛出來。',
  ),

  // 13. 大宮庶民立吞居酒屋牛筋煮
  TravelMaterial(
    id: 'kyoto_omiya_tachinomi',
    name: '大宮庶民立吞居酒屋牛筋煮',
    tags: ['#美食', '#小酌', '#銅板美食'],
    themeValue: 25,
    hypeValue: 25,
    storyValue: 2,
    cost: 600,
    riskLevel: 1,
    description: '擠在下班工薪族之間站著吃一碗滾燙的味噌牛筋，配一杯沁涼生啤。',
    perfectDescription: '擠在下班工薪族之間站著吃一碗滾燙的味噌牛筋，快門捕捉到隔壁大叔正好舉杯朝你碰了一下。',
  ),

  // 14. 三條大橋星巴克鴨川納涼床
  TravelMaterial(
    id: 'kyoto_sanjo_starbucks',
    name: '三條大橋星巴克鴨川納涼床',
    tags: ['#大眾名店', '#小憩', '#咖啡'],
    themeValue: 15,
    hypeValue: 35,
    storyValue: 1,
    cost: 650,
    riskLevel: 1,
    description: '觀光客最愛的鴨川露天平台，點一杯熱拿鐵欣賞對岸的情侶等距排列。',
    perfectDescription: '觀光客最愛的鴨川露天平台，快門落下那刻拿鐵拉花剛好維持著完美的葉脈形狀，還沒被攪散。',
  ),

  // 15. 寺町通地庫古董黑膠爵士喫茶
  TravelMaterial(
    id: 'kyoto_teramachi_record',
    name: '寺町通地庫古董黑膠爵士喫茶',
    tags: ['#巷弄秘境', '#咖啡', '#老街'],
    themeValue: 40,
    hypeValue: 30,
    storyValue: 4,
    cost: 700,
    riskLevel: 1,
    description: '推開厚重木門，管機擴大機播放著 Miles Davis，空氣瀰漫煙草與深烘豆香。',
    perfectDescription: '推開厚重木門，快門定格時唱針正好落在黑膠的起始溝紋，喇叭剛冒出第一個音符。',
  ),

  // 16. 四條大橋街頭三味線龐克彈唱
  TravelMaterial(
    id: 'kyoto_shijo_bridge_busker',
    name: '四條大橋街頭三味線龐克彈唱',
    tags: ['#深夜', '#高風險', '#小酌'],
    themeValue: 25,
    hypeValue: 45,
    storyValue: 3,
    cost: 100,
    riskLevel: 3,
    description: '披著羽織的龐克少年在橋頭激烈刷響三味線，圍觀人潮隨著節拍鼓譟。',
    perfectDescription: '披著羽織的龐克少年在橋頭激烈刷響三味線，快門按下那瞬他的撥子正好脫手飛向半空。',
  ),

  // 17. 三年坂夜間無人石階滑倒詛咒
  TravelMaterial(
    id: 'kyoto_hokanji_slope',
    name: '三年坂夜間無人石階滑倒詛咒',
    tags: ['#老街', '#怪談', '#高風險'],
    themeValue: 30,
    hypeValue: 40,
    storyValue: 4,
    cost: 0,
    riskLevel: 3,
    description: '相傳若在此石階滑倒會減壽三年，夜深無光時每一步都走得膽顫心驚。',
    perfectDescription: '相傳若在此石階滑倒會減壽三年，快門捕捉到一隻黑貓正好穩穩走過最陡的那一階。',
  ),

  // 18. 伊諾達咖啡本店清晨第一杯深焙
  TravelMaterial(
    id: 'kyoto_inoda_coffee',
    name: '伊諾達咖啡本店清晨第一杯深焙',
    tags: ['#早餐', '#老街', '#大眾名店'],
    themeValue: 30,
    hypeValue: 30,
    storyValue: 3,
    cost: 800,
    riskLevel: 1,
    description: '京都人的早晨從「阿拉伯珍珠」開始，銀製方糖罐與復古紅絲絨沙發。',
    perfectDescription: '京都人的早晨從「阿拉伯珍珠」開始，快門落下時老闆娘正好把方糖罐輕輕放回你手邊。',
  ),

  // 19. 清水寺夜間特別參拜赤紅舞台 (Spotlight)
  TravelMaterial(
    id: 'kyoto_kiyomizu_stage',
    name: '清水寺夜間特別參拜赤紅舞台',
    tags: ['#絕景', '#古蹟', '#大眾名店'],
    themeValue: 40,
    hypeValue: 80,
    isSpotlight: true,
    storyValue: 4,
    cost: 1000,
    riskLevel: 2,
    description: '懸空舞台投射出筆直藍色觀音慈光，楓紅在黑夜中宛如熊熊燃燒的火焰。',
    perfectDescription: '懸空舞台投射出筆直藍色觀音慈光，快門定格那刻一片楓葉正好飄進光束中央，像是被點燃一樣。',
    failedDescription: '懸空舞台投射出筆直藍色觀音慈光，前排遊客的自拍補光燈忽然亮起，把半個舞台照成慘白色。',
  ),

  // 20. 二寧坂塌榻米老屋星巴克
  TravelMaterial(
    id: 'kyoto_ninenzaka_tatami',
    name: '二寧坂塌榻米老屋星巴克',
    tags: ['#老街', '#巷弄秘境', '#咖啡'],
    themeValue: 25,
    hypeValue: 30,
    storyValue: 2,
    cost: 500,
    riskLevel: 1,
    description: '改建自百年數寄屋造老民宅，脫鞋坐在榻榻米上捧著紙杯的奇妙違和感。',
    perfectDescription: '改建自百年數寄屋造老民宅，快門按下瞬間窗外一陣風正好吹動紙拉門，光影恰好落在紙杯上。',
  ),

  // 21. 六波羅蜜寺幽靈子育飴百年老鋪
  TravelMaterial(
    id: 'kyoto_rokuharamitsuji',
    name: '六波羅蜜寺幽靈子育飴百年老鋪',
    tags: ['#老街', '#怪談', '#銅板美食'],
    themeValue: 35,
    hypeValue: 25,
    storyValue: 4,
    cost: 300,
    riskLevel: 1,
    description: '四百年歷史的水飴老鋪，相傳江戶時代每晚有亡魂女子來此買糖哺育嬰兒。',
    perfectDescription: '四百年歷史的水飴老鋪，快門定格那刻老闆正好遞出一枚糖，包裝紙的反光剛好映出你的臉。',
  ),

  // 22. 嵯峨野無人月台末班柴油車
  TravelMaterial(
    id: 'kyoto_sagano_torokko',
    name: '嵯峨野無人月台末班柴油車',
    tags: ['#拉車', '#深夜', '#高風險'],
    themeValue: 30,
    hypeValue: 40,
    storyValue: 4,
    cost: 600,
    riskLevel: 3,
    description: '遠離市區的寂靜車站，單節車廂在寒夜中噴吐著柴油白煙發動。',
    perfectDescription: '遠離市區的寂靜車站，快門按下那瞬柴油白煙正好被車頭燈打成一團發光的雲。',
  ),

  // 23. 祇園巷深無菜單板前割烹料理
  TravelMaterial(
    id: 'kyoto_gion_kappo',
    name: '祇園巷深無菜單板前割烹料理',
    tags: ['#美食', '#大眾名店', '#老街'],
    themeValue: 40,
    hypeValue: 55,
    storyValue: 5,
    cost: 5000,
    riskLevel: 1,
    description: '沒有招牌的檜木門扉，主廚現場刀剖若狹灣直送天然赤鯛。',
    perfectDescription: '沒有招牌的檜木門扉，快門捕捉到主廚刀鋒切開魚身的瞬間，斷面泛著粉色光澤。',
  ),

  // 24. 宇治川十三重石塔深夜霧氣
  TravelMaterial(
    id: 'kyoto_ujigawa_night',
    name: '宇治川十三重石塔深夜霧氣',
    tags: ['#拉車', '#巷弄秘境', '#古蹟'],
    themeValue: 35,
    hypeValue: 35,
    storyValue: 3,
    cost: 400,
    riskLevel: 2,
    description: '深夜中之島公園泛起濃重河霧，十三重石塔在霧中隱隱如水墨畫。',
    perfectDescription: '深夜中之島公園泛起濃重河霧，快門定格那刻一陣風正好吹散塔尖前的霧氣，露出完整輪廓。',
  ),

  // 25. 鴨川沿岸手沖咖啡流動單車
  TravelMaterial(
    id: 'kyoto_kamo_kamome',
    name: '鴨川沿岸手沖咖啡流動單車',
    tags: ['#巷弄秘境', '#咖啡', '#散步'],
    themeValue: 25,
    hypeValue: 35,
    storyValue: 3,
    cost: 500,
    riskLevel: 1,
    description: '踩著老式貨運自行車的青年，在河岸點亮一盞露營燈現場手沖淺焙耶加雪菲。',
    perfectDescription: '踩著老式貨運自行車的青年，快門按下瞬間手沖壺的水柱正好畫出一道完美的螺旋線。',
  ),

  // 26. 千本閻魔堂深夜祈願鐘聲
  TravelMaterial(
    id: 'kyoto_senbon_enmado',
    name: '千本閻魔堂深夜祈願鐘聲',
    tags: ['#深夜', '#怪談', '#古蹟'],
    themeValue: 35,
    hypeValue: 30,
    storyValue: 4,
    cost: 100,
    riskLevel: 2,
    description: '紫野平安京故道上的古剎，低沉鐘聲穿過長夜，洗滌過客一身業障。',
    perfectDescription: '紫野平安京故道上的古剎，快門定格時撞鐘的木槌正好觸及鐘面，振動的漣漪清晰可見。',
  ),

  // 27. 北野天滿宮天神市手作跳蚤古物
  TravelMaterial(
    id: 'kyoto_kitano_tenmangu_market',
    name: '北野天滿宮天神市手作跳蚤古物',
    tags: ['#老街', '#巷弄秘境', '#銅板美食'],
    themeValue: 30,
    hypeValue: 35,
    storyValue: 3,
    cost: 300,
    riskLevel: 1,
    description: '神社境內攤位林立，在古董陶瓷、老著物與章魚燒香氣中挖寶。',
    perfectDescription: '神社境內攤位林立，快門按下瞬間老闆娘正好舉起一件老著物給你看袖口的刺繡細節。',
  ),

  // 28. 大文字山深夜夜爬鳥瞰全京都 (Spotlight)
  TravelMaterial(
    id: 'kyoto_daimonji_night_hike',
    name: '大文字山深夜夜爬鳥瞰全京都',
    tags: ['#高風險', '#深夜', '#拉車', '#絕景'],
    themeValue: 45,
    hypeValue: 80,
    isSpotlight: true,
    storyValue: 5,
    cost: 0,
    riskLevel: 5,
    description: '手持微弱手電筒摸黑攀登銀閣寺後山，在火床處迎來整座京都市無邊無際的璀璨夜景。',
    perfectDescription: '手持微弱手電筒摸黑攀登銀閣寺後山，快門定格那刻雲層正好裂開一道縫，月光灑在整片京都夜景上。',
    failedDescription: '手持微弱手電筒摸黑攀登銀閣寺後山，同行山友的頭燈忽然轉向你，鏡頭裡只剩一片刺眼的白光。',
  ),

  // 29. 高野川夜半螢火與流水聲
  TravelMaterial(
    id: 'kyoto_takano_river_firefly',
    name: '高野川夜半螢火與流水聲',
    tags: ['#深夜', '#散步', '#巷弄秘境'],
    themeValue: 35,
    hypeValue: 30,
    storyValue: 3,
    cost: 0,
    riskLevel: 2,
    description: '初夏沿著高野川河堤漫步，草叢中微弱綠光此起彼落，靜謐無人。',
    perfectDescription: '初夏沿著高野川河堤漫步，快門按下瞬間三隻螢火蟲正好連成一線，像串起的一條光之項鍊。',
  ),

  // 30. 新京極昭和洋食立飲老店
  TravelMaterial(
    id: 'kyoto_kyogoku_stand',
    name: '新京極昭和洋食立飲老店',
    tags: ['#美食', '#老街', '#銅板美食'],
    themeValue: 25,
    hypeValue: 30,
    storyValue: 3,
    cost: 750,
    riskLevel: 1,
    description: '昭和四十二年創業的立飲吧，招牌炸火腿排佐黃芥末配角瓶威士忌 Highball。',
    perfectDescription: '昭和四十二年創業的立飲吧，快門定格那刻氣泡水正好注入角瓶威士忌，泡沫還沒散去。',
  ),

  // 31. 一乘寺激戰區深夜極濃豚骨拉麵
  TravelMaterial(
    id: 'kyoto_ichijoji_ramen_street',
    name: '一乘寺激戰區深夜極濃豚骨拉麵',
    tags: ['#美食', '#拉車', '#深夜'],
    themeValue: 30,
    hypeValue: 45,
    storyValue: 3,
    cost: 950,
    riskLevel: 2,
    description: '在拉麵激戰區頂著寒風排隊四十分鐘，插筷不倒的極致濃湯黏唇甘香。',
    perfectDescription: '在拉麵激戰區頂著寒風排隊四十分鐘，快門按下瞬間筷子插進湯裡正好穩穩立住，沒有倒下。',
  ),

  // 32. 無鄰菴庭園夜間特別開放青苔
  TravelMaterial(
    id: 'kyoto_murin_an_night_moss',
    name: '無鄰菴庭園夜間特別開放青苔',
    tags: ['#老街', '#巷弄秘境', '#古蹟'],
    themeValue: 40,
    hypeValue: 40,
    storyValue: 4,
    cost: 1500,
    riskLevel: 1,
    description: '引入琵琶湖疏水之名勝庭園，夜間低矮投射光勾勒出青苔與溪流的雅緻曲線。',
    perfectDescription: '引入琵琶湖疏水之名勝庭園，快門定格那刻一滴夜露正好從青苔滑落溪流，激起一圈極細的漣漪。',
  ),
];
