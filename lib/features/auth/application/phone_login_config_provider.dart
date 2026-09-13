import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/json_field_parser.dart';
import 'facebook_login_config_provider.dart';

/// 是否展示手机号登录入口。
///
/// 手机号登录配置接口尚未提供；保留独立 provider 作为唯一开关接入点，避免 UI
/// 在接口上线时再散落条件判断。接口接入后在这里替换为服务端读取即可。
final phoneLoginEnabledProvider = FutureProvider<bool>(
  (ref) async => (await ref.watch(loginConfigProvider.future)).phoneVisible,
);

final phoneSmsServiceProvider = Provider<PhoneSmsService>(
  (ref) => PhoneSmsService(ref.watch(apiClientProvider)),
);

class PhoneSmsService {
  const PhoneSmsService(this._apiClient);

  final ApiClient _apiClient;

  Future<PhoneSmsSendCodeResult> sendCode({
    required String callingCode,
    required String number,
    required String requestId,
  }) {
    return _apiClient.post<PhoneSmsSendCodeResult>(
      '/api/login/sms/send-code',
      authPolicy: ApiAuthPolicy.required,
      data: {
        'calling_code': callingCode,
        'number': number,
        'request_id': requestId,
      },
      decoder: PhoneSmsSendCodeResult.fromJson,
    );
  }

  Future<PhoneSmsVerifyResult> verifyCode({
    required String callingCode,
    required String number,
    required String code,
  }) => _apiClient.post<PhoneSmsVerifyResult>(
    '/api/login/sms/verify-code',
    authPolicy: ApiAuthPolicy.required,
    data: {'calling_code': callingCode, 'number': number, 'code': code},
    decoder: PhoneSmsVerifyResult.fromJson,
  );
}

class PhoneSmsVerifyResult {
  const PhoneSmsVerifyResult({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpireAt,
    required this.refreshExpireAt,
    required this.userId,
  });
  factory PhoneSmsVerifyResult.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(json, dtoName: 'VerifyCodeResponse');
    return PhoneSmsVerifyResult(
      accessToken: JsonFieldParser.requireString(
        map,
        'access_token',
        dtoName: 'VerifyCodeResponse',
      ),
      refreshToken: JsonFieldParser.requireString(
        map,
        'refresh_token',
        dtoName: 'VerifyCodeResponse',
      ),
      accessExpireAt: JsonFieldParser.requireInt(
        map,
        'access_expire_at',
        dtoName: 'VerifyCodeResponse',
      ),
      refreshExpireAt: JsonFieldParser.requireInt(
        map,
        'refresh_expire_at',
        dtoName: 'VerifyCodeResponse',
      ),
      userId: JsonFieldParser.requireInt(
        map,
        'user_id',
        dtoName: 'VerifyCodeResponse',
      ),
    );
  }
  final String accessToken;
  final String refreshToken;
  final int accessExpireAt;
  final int refreshExpireAt;
  final int userId;
}

class PhoneSmsSendCodeResult {
  const PhoneSmsSendCodeResult({
    required this.codeExpireSeconds,
    required this.countdownSeconds,
  });

  factory PhoneSmsSendCodeResult.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(json, dtoName: 'SendCodeResponse');
    return PhoneSmsSendCodeResult(
      codeExpireSeconds: JsonFieldParser.requireInt(
        map,
        'code_expire_seconds',
        dtoName: 'SendCodeResponse',
      ),
      countdownSeconds: JsonFieldParser.requireInt(
        map,
        'countdown_seconds',
        dtoName: 'SendCodeResponse',
      ),
    );
  }

  final int codeExpireSeconds;
  final int countdownSeconds;
}

final phoneRegionsProvider = FutureProvider<List<PhoneRegion>>((ref) async {
  try {
    final regions = await ref
        .watch(apiClientProvider)
        .get<List<PhoneRegion>>(
          '/api/phone/regions',
          authPolicy: ApiAuthPolicy.required,
          decoder: (data) => JsonFieldParser.requireList(
            data,
            dtoName: 'PhoneRegionsResponse',
          ).map(PhoneRegion.fromJson).toList(),
        );
    return _sortPhoneRegions(regions);
  } catch (_) {
    return _fallbackPhoneRegionsFor(
      ref.read(apiRequestContextProvider).regionCode,
    );
  }
});

class PhoneRegion {
  const PhoneRegion({
    required this.callingCode,
    required this.isDefault,
    required this.expressions,
    required this.regionCode,
    this.regionName,
  });
  factory PhoneRegion.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(json, dtoName: 'PhoneRegionItem');
    return PhoneRegion(
      callingCode: (map['calling_code'] as String? ?? '').trim(),
      isDefault: map['default'] == true,
      expressions: JsonFieldParser.requireList(
        map['expr'] ?? const [],
        dtoName: 'PhoneRegionItem',
        field: 'expr',
      ).whereType<String>().where((v) => v.isNotEmpty).toList(),
      regionCode: JsonFieldParser.requireString(
        map,
        'region_code',
        dtoName: 'PhoneRegionItem',
      ).trim().toLowerCase(),
      regionName: JsonFieldParser.optionalString(map, 'region_name')?.trim(),
    );
  }
  final String callingCode;
  final bool isDefault;
  final List<String> expressions;
  final String regionCode;
  final String? regionName;
  String get displayName => regionName == null || regionName!.isEmpty
      ? regionCode.toUpperCase()
      : regionName!;
  String get callingCodeLabel => callingCode.isEmpty ? '' : '+$callingCode';
  bool matches(String number) =>
      expressions.isEmpty ||
      expressions.any((value) => RegExp(value).hasMatch(number));
}

List<PhoneRegion> _sortPhoneRegions(Iterable<PhoneRegion> regions) {
  final sortedRegions = List<PhoneRegion>.of(regions);
  sortedRegions.sort((a, b) {
    if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
    return a.regionCode.compareTo(b.regionCode);
  });
  return sortedRegions;
}

/// 区号服务不可用时使用的本地兜底数据。仅包含已分配国际区号的地区。
final List<PhoneRegion> _fallbackPhoneRegions = _sortPhoneRegions(
  _fallbackPhoneRegionData.split(',').map((value) {
    final fields = value.split(':');
    final regionCode = fields[0];
    return PhoneRegion(
      regionCode: regionCode,
      callingCode: fields[1],
      isDefault: regionCode == 'ph',
      expressions: regionCode == 'ph'
          ? const [r'^0?[89]\d{9}$', r'^\+63[89]\d{9}$', r'^63[89]\d{9}$']
          : const [],
    );
  }),
);

/// 兜底列表不依赖服务端 `default` 配置：优先使用请求上下文里的设备地区，
/// 设备地区不可用或不在列表中时固定选择 PH。
List<PhoneRegion> _fallbackPhoneRegionsFor(String regionCode) {
  final preferredCode = regionCode.trim().toLowerCase();
  final selectedCode =
      _fallbackPhoneRegions.any((region) => region.regionCode == preferredCode)
      ? preferredCode
      : 'ph';

  return _sortPhoneRegions(
    _fallbackPhoneRegions.map(
      (region) => PhoneRegion(
        callingCode: region.callingCode,
        isDefault: region.regionCode == selectedCode,
        expressions: region.expressions,
        regionCode: region.regionCode,
        regionName: region.regionName,
      ),
    ),
  );
}

const _fallbackPhoneRegionData =
    'ph:63,ae:971,af:93,ag:1,ai:1,al:355,am:374,ao:244,ar:54,as:1,at:43,au:61,aw:297,ax:358,az:994,ba:387,bb:1,bd:880,be:32,bf:226,bg:359,bh:973,bi:257,bj:229,bl:590,bm:1,bn:673,bo:591,bq:599,br:55,bs:1,bt:975,bw:267,by:375,bz:501,ca:1,cc:61,cd:243,cf:236,cg:242,ch:41,ci:225,ck:682,cl:56,cm:237,cn:86,co:57,cr:506,cu:53,cv:238,cw:599,cx:61,cy:357,cz:420,de:49,dj:253,dk:45,dm:1,do:1,dz:213,ec:593,ee:372,eg:20,eh:212,er:291,es:34,et:251,fi:358,fj:679,fk:500,fm:691,fo:298,fr:33,ga:241,gb:44,gd:1,ge:995,gf:594,gg:44,gh:233,gi:350,gl:299,gm:220,gn:224,gp:590,gq:240,gr:30,gt:502,gu:1,gw:245,gy:592,hk:852,hn:504,hr:385,ht:509,hu:36,id:62,ie:353,il:972,im:44,in:91,io:246,iq:964,ir:98,is:354,it:39,je:44,jm:1,jo:962,jp:81,ke:254,kg:996,kh:855,ki:686,km:269,kn:1,kp:850,kr:82,kw:965,ky:1,kz:7,la:856,lb:961,lc:1,li:423,lk:94,lr:231,ls:266,lt:370,lu:352,lv:371,ly:218,ma:212,mc:377,md:373,me:382,mf:590,mg:261,mh:692,mk:389,ml:223,mm:95,mn:976,mo:853,mp:1,mq:596,mr:222,ms:1,mt:356,mu:230,mv:960,mw:265,mx:52,my:60,mz:258,na:264,nc:687,ne:227,nf:672,ng:234,ni:505,nl:31,no:47,np:977,nr:674,nu:683,nz:64,om:968,pa:507,pe:51,pf:689,pg:675,ad:376,pk:92,pl:48,pm:508,pn:870,pr:1,ps:970,pt:351,pw:680,py:595,qa:974,re:262,ro:40,rs:381,ru:7,rw:250,sa:966,sb:677,sc:248,sd:249,se:46,sg:65,sh:290,si:386,sj:47,sk:421,sl:232,sm:378,sn:221,so:252,sr:597,ss:211,st:239,sv:503,sx:599,sy:963,sz:268,tc:1,td:235,tg:228,th:66,tj:992,tk:690,tl:670,tm:993,tn:216,to:676,tr:90,tt:1,tv:688,tw:886,tz:255,ua:380,ug:256,um:1,us:1,uy:598,uz:998,va:379,vc:1,ve:58,vg:1,vi:1,vn:84,vu:678,wf:681,ws:685,ye:967,yt:262,za:27,zm:260,zw:263';
