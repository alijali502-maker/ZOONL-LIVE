import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserLevelScreen extends StatefulWidget {
  const UserLevelScreen({super.key});
  @override
  State<UserLevelScreen> createState() => _UserLevelScreenState();
}

class _UserLevelScreenState extends State<UserLevelScreen> with TickerProviderStateMixin {
  final _db = Supabase.instance.client;
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200))..repeat(reverse: true);
  bool _loading = true, _owner = false;
  String? _error;
  int _level = 1, _exp = 0;
  String _prime = 'Checking…', _entry = 'Checking…', _frame = 'Checking…', _badge = 'Checking…';
  List<Map<String,dynamic>> _levels = [];
  List<Map<String,dynamic>> _backpack = [];

  static const _palettes = <List<Color>>[
    [Color(0xFF607D8B),Color(0xFFCFD8DC),Color(0xFF263746)],
    [Color(0xFF287A9D),Color(0xFF8CEBFF),Color(0xFF16405D)],
    [Color(0xFF7151A5),Color(0xFFD2B5FF),Color(0xFF34205E)],
    [Color(0xFFAD5A26),Color(0xFFFFD18A),Color(0xFF663016)],
    [Color(0xFF9A315F),Color(0xFFFFB2D1),Color(0xFF541A3C)],
    [Color(0xFF168B91),Color(0xFF9DFFFF),Color(0xFF07545C)],
    [Color(0xFF9D2E34),Color(0xFFFFA69B),Color(0xFF54151D)],
    [Color(0xFF9A6A16),Color(0xFFFFE89B),Color(0xFF56370C)],
    [Color(0xFF8B3D77),Color(0xFFFFB7EA),Color(0xFF4B1B4B)],
    [Color(0xFFB57A20),Color(0xFFFFF0AE),Color(0xFF62400C)],
  ];
  int _tier(int n) => n >= 100 ? 9 : n <= 10 ? n-1 : ((n-1) ~/ 10).clamp(1,9).toInt();
  List<Color> _colors(int n) {
    if (n >= 100) return const [Color(0xFFFFE6A1),Color(0xFFFFFFFF),Color(0xFFB77A22),Color(0xFF57320D)];
    final base = _palettes[_tier(n)];
    final shift = (n % 10) * 3.2;
    Color vary(Color c) {
      final hsv = HSVColor.fromColor(c);
      return hsv.withHue((hsv.hue + shift) % 360).toColor();
    }
    return [vary(base[0]), vary(base[1]), vary(base[2])];
  }
  String _name(int n) {
    if(n>=100) return 'SOVEREIGN OWNER';
    const titles=['ROOKIE','RISING','FALCON','LIONHEART','PALACE','MILLIONAIRE','SULTAN','ROYAL','EMPEROR','LEGEND'];
    return '${titles[_tier(n)]} • LEVEL $n';
  }
  String _rankName(int level) {
    for (final row in _levels) {
      if ((row['level'] as num?)?.toInt() == level) {
        final configured = row['level_name']?.toString().trim() ?? '';
        if (configured.isNotEmpty) return configured;
      }
    }
    return _name(level);
  }

  String _fmt(int n) => n>=1000000000 ? '${(n/1000000000).toStringAsFixed(2)}B' :
      n>=1000000 ? '${(n/1000000).toStringAsFixed(2)}M' :
      n>=1000 ? '${(n/1000).toStringAsFixed(1)}K' : '$n';

  @override void initState(){super.initState();_load();}
  @override void dispose(){_shine.dispose();_float.dispose();super.dispose();}

  Future<void> _load() async {
    final user=_db.auth.currentUser;
    if(user==null){if(mounted)setState((){_loading=false;_error='Login required.';});return;}
    setState(()=>_loading=true);
    try{
      final r=await Future.wait<dynamic>([
        _db.rpc('zoonl_my_level'),
        _db.rpc('zoonl_my_lifetime_gift_exp'),
        _db.from('level_definitions').select('level,required_exp,level_name,level_config').order('level'),
        _db.rpc('is_zoonl_owner'),
        _db.from('user_prime_memberships').select('expires_at,is_active').eq('user_id',user.id).eq('is_active',true),
        _db.from('zoonl_live_user_baggage').select('zoonl_item_code,item_type,is_equipped,expires_at').eq('user_id',user.id).eq('project_name','ZOONL LIVE'),
        _db.from('zoonl_live_cosmetics').select('zoonl_item_code,zoonl_item_name,media_url,color_theme_hex,item_type').eq('project_name','ZOONL LIVE').eq('is_active',true),
        _db.from('prime_tiers').select('id,tier_name').eq('is_active',true),
      ]);
      final now=DateTime.now();
      bool valid(Map e){final x=e['expires_at'];return x==null||(DateTime.tryParse(x.toString())?.isAfter(now)??false);}
      final inventory=r[5] as List;
      final catalogByCode=<String,Map<String,dynamic>>{
        for(final row in (r[6] as List))
          (row['zoonl_item_code']??'').toString():Map<String,dynamic>.from(row as Map),
      };
      final activeMembership=(r[4] as List)
          .map((e)=>Map<String,dynamic>.from(e as Map))
          .where(valid).toList();
      final activePrime=activeMembership.isNotEmpty;
      final primeNames=<int,String>{
        for(final tier in (r[7] as List))
          (tier['id'] as num).toInt():tier['tier_name'].toString(),
      };
      final entries=inventory.where((e)=>e['item_type']=='ENTRY_EFFECT'&&valid(Map<String,dynamic>.from(e))).toList();
      if(!mounted)return;
      setState((){
        _level=((r[0] as num?)?.toInt()??1).clamp(1,100).toInt();
        _exp=(r[1] as num?)?.toInt()??0;
        _levels=(r[2] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
        _backpack=inventory.map((e){final item=Map<String,dynamic>.from(e as Map);item['_catalog']=catalogByCode[item['zoonl_item_code']?.toString()??''];return item;}).toList();
        _owner=r[3]==true;
        _prime=activePrime?(primeNames[(activeMembership.first['prime_tier_id'] as num?)?.toInt()]??'ACTIVE'):'Not assigned';
        _entry=entries.isEmpty?'No active Entry':entries.map((e)=>e['zoonl_item_code'].toString()).join(', ');
        _frame=inventory.any((e)=>e['zoonl_item_code']=='ZOONL_SOVEREIGN_OWNER_FRAME'&&valid(Map<String,dynamic>.from(e)))?'Sovereign Crown ID Frame':'Not found';
        _badge=inventory.any((e)=>e['zoonl_item_code']=='ZOONL_OWNER_BADGE'&&valid(Map<String,dynamic>.from(e)))?'Sovereign VIP badge':'Not found';
        _loading=false;_error=null;
      });
    }catch(e){if(mounted)setState((){_loading=false;_error=e.toString();});}
  }

  Future<void> _equipBackpackItem(Map<String, dynamic> item) async {
    final code = item['zoonl_item_code']?.toString() ?? '';
    if (code.isEmpty) return;
    try {
      await _db.rpc('equip_zoonl_cosmetic', params: <String, dynamic>{'p_item_code': code});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${code.replaceAll('_', ' ')} equipped')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not equip item: $e')),
      );
    }
  }

  bool validBackpackItem(Map<String,dynamic> item) {
    final expiry=item['expires_at'];
    return expiry==null||(DateTime.tryParse(expiry.toString())?.isAfter(DateTime.now())??false);
  }

  Widget _glass(Widget child,Color c,{EdgeInsets padding=const EdgeInsets.all(15)})=>ClipRRect(
    borderRadius:BorderRadius.circular(19),
    child:BackdropFilter(filter:ImageFilter.blur(sigmaX:15,sigmaY:15),child:Container(
      padding:padding,
      decoration:BoxDecoration(color:const Color(0xD90C101B),borderRadius:BorderRadius.circular(19),
        border:Border.all(color:c.withOpacity(.46),width:1.1),
        boxShadow:[BoxShadow(color:c.withOpacity(.15),blurRadius:22),const BoxShadow(color:Colors.black54,blurRadius:18,offset:Offset(0,9))]),
      child:child)));

  Widget _emblem(int n,{double size=90,bool animated=true}){
    final colors=_colors(n);
    Widget face(double sweep,double rotation)=>Transform(
      alignment:Alignment.center,
      transform:Matrix4.identity()..setEntry(3,2,.002)..rotateY(rotation),
      child:SizedBox(width:size*1.2,height:size*1.28,child:Stack(alignment:Alignment.center,children:[
        CustomPaint(size:Size(size*1.08,size*1.16),painter:_EmblemPainter(colors:colors,tier:_tier(n),shine:sweep,owner:n>=100,level:n)),
        Positioned(top:size*.36,child:Text('$n',style:TextStyle(color:Colors.white,fontSize:size*.27,fontWeight:FontWeight.w900,
          shadows:[Shadow(color:Colors.black,blurRadius:5,offset:Offset(1,3)),Shadow(color:colors[1],blurRadius:size*.16)]))),
        Positioned(bottom:size*.15,child:Text(n>=100?'VIP':n<=10?'RANK':'ELITE',
          style:TextStyle(color:Colors.white,fontSize:size*.075,fontWeight:FontWeight.w900,letterSpacing:1.5,
            shadows:[Shadow(color:colors[1],blurRadius:8)]))),
      ])));
    if(!animated)return face(.32,0);
    return AnimatedBuilder(animation:Listenable.merge([_shine,_float]),builder:(context,_)=>
      face(_shine.value,math.sin(_float.value*math.pi*2)*.035));
  }

  Widget _bar(double v,List<Color> c)=>ClipRRect(borderRadius:BorderRadius.circular(20),child:Stack(children:[
    Container(height:13,color:Colors.white12),
    FractionallySizedBox(widthFactor:v.clamp(0.0,1.0).toDouble(),child:Container(height:13,decoration:BoxDecoration(
      gradient:LinearGradient(colors:[c.last,c.first,Colors.white]),boxShadow:[BoxShadow(color:c[1].withOpacity(.8),blurRadius:12)]))),
    Positioned.fill(child:IgnorePointer(child:AnimatedBuilder(animation:_shine,builder:(_,__)=>Align(
      alignment:Alignment(-1+_shine.value*2,0),child:Container(width:25,height:13,
        decoration:BoxDecoration(gradient:LinearGradient(colors:[Colors.transparent,Colors.white70,Colors.transparent]))))))),
  ]));

  Widget _metric(String title,String value)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(color:Colors.white54,fontSize:7,fontWeight:FontWeight.w800)),
    const SizedBox(height:4),Text(value,style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w900))]);

  Widget _status(IconData icon,String title,String value,Color color)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[
      Container(width:36,height:36,decoration:BoxDecoration(gradient:LinearGradient(colors:[color.withOpacity(.3),Colors.black54]),
        borderRadius:BorderRadius.circular(11),border:Border.all(color:color.withOpacity(.7)),
        boxShadow:[BoxShadow(color:color.withOpacity(.18),blurRadius:12)]),child:Icon(icon,color:color,size:18)),
      const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(color:Colors.white60,fontSize:10,fontWeight:FontWeight.w800)),
        Text(value,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w800))]))]));

  Widget _row(Map<String,dynamic> data){
    final n=(data['level'] as num).toInt(),goal=(data['required_exp'] as num).toInt();
    final reached=n<=_level,active=n==_level,c=_colors(n);
    return Padding(padding:const EdgeInsets.only(bottom:8),child:_glass(Row(children:[
      SizedBox(width:49,height:51,child:_emblem(n,size:36,animated:false)),
      const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(_rankName(n),style:TextStyle(color:reached?Colors.white:Colors.white38,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.5)),
        const SizedBox(height:4),Text('Lifetime target  ${_fmt(goal)} EXP',style:const TextStyle(color:Colors.white54,fontSize:9))])),
      Icon(active?Icons.auto_awesome:reached?Icons.verified:Icons.lock_outline,color:active||reached?c[1]:Colors.white24,size:18),
    ]),active?c[1]:reached?c[0]:Colors.white24,padding:const EdgeInsets.symmetric(horizontal:11,vertical:8)));
  }

  @override Widget build(BuildContext context){
    Map<String,dynamic>? current,next;
    for(final r in _levels){final n=(r['level'] as num).toInt();if(n==100&&!_owner)continue;if(n==_level)current=r;if(n>_level&&next==null)next=r;}
    final start=(current?['required_exp'] as num?)?.toInt()??0;
    final target=(next?['required_exp'] as num?)?.toInt()??start;
    final remain=(target-_exp).clamp(0,target).toInt();
    final progress=next==null?1.0:((_exp-start)/(target-start).clamp(1,1<<62)).clamp(0.0,1.0).toDouble();
    final c=_colors(_level);
    return Scaffold(backgroundColor:const Color(0xFF070A12),appBar:AppBar(
      title:const Text('LEVEL & RANK CENTER',style:TextStyle(fontSize:13,letterSpacing:1,fontWeight:FontWeight.w900)),
      backgroundColor:const Color(0xFF080B13),actions:[IconButton(onPressed:_loading?null:_load,icon:const Icon(Icons.refresh))]),
      body:_loading?const Center(child:CircularProgressIndicator()):_error!=null
        ?Center(child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(_error!,textAlign:TextAlign.center),const SizedBox(height:12),OutlinedButton(onPressed:_load,child:const Text('RETRY'))])))
        :RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(14),children:[
          _glass(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[const Expanded(child:Text('YOUR CURRENT RANK',style:TextStyle(color:Colors.white60,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.6))),
              if(_owner)Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(
                gradient:const LinearGradient(colors:[Color(0xFFFFF2BE),Color(0xFFB87A22),Color(0xFFFFE8A0)]),
                borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white),
                boxShadow:const [BoxShadow(color:Color(0x99E8C46E),blurRadius:14)]),
                child:const Text('✦ SOVEREIGN OWNER',style:TextStyle(color:Color(0xFF3B2509),fontSize:8,fontWeight:FontWeight.w900)))]),
            const SizedBox(height:7),Row(children:[_emblem(_level),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(_rankName(_level),style:TextStyle(color:c[1],fontSize:13,fontWeight:FontWeight.w900)),
              const SizedBox(height:5),Text('${_fmt(_exp)} EXP',style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),
              const Text('LIFETIME GIFT EXP • RECORD KEPT',style:TextStyle(color:Colors.white54,fontSize:8,letterSpacing:1))]))]),
            const SizedBox(height:12),Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(
              color:Colors.black38,borderRadius:BorderRadius.circular(12),border:Border.all(color:c[1].withOpacity(.22))),
              child:Row(children:[Expanded(child:_metric('CURRENT LEVEL','$_level')),Expanded(child:_metric('NEXT RANK',next==null?'MAX':'${next['level']}')),
                Expanded(child:_metric('REMAINING',next==null?'—':_fmt(remain)))])),
            const SizedBox(height:12),Row(children:[const Expanded(child:Text('NEXT LEVEL PROGRESS',style:TextStyle(color:Colors.white70,fontSize:9,fontWeight:FontWeight.w900))),
              Text(next==null?'MAX RANK':'${(progress*100).round()}%',style:TextStyle(color:c[1],fontWeight:FontWeight.w900,fontSize:10))]),
            const SizedBox(height:8),_bar(progress,c),const SizedBox(height:7),
            Text(next==null?'Highest rank configured.':'${_fmt(_exp)} / ${_fmt(target)} EXP • ${_fmt(remain)} EXP left',
              style:const TextStyle(color:Colors.white60,fontSize:10)),
          ]),c[1]),
          const SizedBox(height:12),
          _glass(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const Icon(Icons.inventory_2_outlined,color:Color(0xFFE6C47A),size:17),
              const SizedBox(width:7),
              const Expanded(child:Text('MY BACKPACK',style:TextStyle(color:Color(0xFFFFE6A1),fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.1))),
              Text('${_backpack.length} ITEMS',style:const TextStyle(color:Colors.white54,fontSize:8,fontWeight:FontWeight.w800)),
            ]),
            const SizedBox(height:5),
            if(_backpack.isEmpty)
              const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('Your owned frames, entries and effects will appear here.',style:TextStyle(color:Colors.white54,fontSize:10)))
            else
              for(final item in _backpack.where((e)=>validBackpackItem(e)))
                Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[
                  Container(width:34,height:34,decoration:BoxDecoration(
                    gradient:const LinearGradient(colors:[Color(0xFF3C285C),Color(0xFF171126)]),
                    borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0x66E6C47A))),
                    child:Icon(item['item_type']=='ENTRY_EFFECT'?Icons.bolt:item['item_type']=='FRAME'?Icons.crop_square:Icons.auto_awesome,
                      color:const Color(0xFFE6C47A),size:17)),
                  const SizedBox(width:9),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text((((item['_catalog'] as Map?)?['zoonl_item_name']) ?? (item['zoonl_item_code']??'ZOONL ITEM')).toString(),
                      style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900)),
                    Text((item['item_type']??'COSMETIC').toString().replaceAll('_',' '),
                      style:const TextStyle(color:Colors.white54,fontSize:8)),
                  ])),
                  if(item['is_equipped']==true)
                    const Text('EQUIPPED',style:TextStyle(color:Color(0xFF8DE6C0),fontSize:7,fontWeight:FontWeight.w900))
                  else
                    TextButton(
                      onPressed: () => _equipBackpackItem(item),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFFE6A1),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('EQUIP', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                ])),
          ]),const Color(0xFFE6C47A)),
          if(_owner)...[
            const SizedBox(height:12),_glass(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('SOVEREIGN OWNER ENTITLEMENTS',style:TextStyle(color:Color(0xFFFFE6A1),fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.1)),
              _status(Icons.verified_user,'Trusted Owner','Verified by Supabase authority',const Color(0xFFFFD98B)),
              _status(Icons.workspace_premium,'Prime membership',_prime,const Color(0xFFC9A7FF)),
              _status(Icons.bolt,'Royal entry',_entry,const Color(0xFF8BEAFF)),
              _status(Icons.shield,'Imperial frame',_frame,const Color(0xFFFFA9D6)),
              _status(Icons.military_tech,'VIP identity badge',_badge,const Color(0xFFFFE6A1)),
            ]),const Color(0xFFFFE6A1)),
          ],
          const SizedBox(height:19),const Text('RANK LADDER',style:TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w900,letterSpacing:1.2)),
          const SizedBox(height:4),const Text('Lifetime EXP stays with your account. Every next rank has a higher target.',style:TextStyle(color:Colors.white54,fontSize:10)),
          const SizedBox(height:10),
          for(final r in _levels.where((r)=>(r['level'] as num).toInt()<100))_row(r),
          if(_owner&&_levels.any((r)=>(r['level'] as num).toInt()==100))_row(_levels.firstWhere((r)=>(r['level'] as num).toInt()==100)),
        ])));
  }
}

class _EmblemPainter extends CustomPainter{
  final List<Color> colors;final int tier;final double shine;final bool owner;final int level;
  _EmblemPainter({required this.colors,required this.tier,required this.shine,required this.owner,required this.level});
  @override void paint(Canvas canvas,Size s){
    final w=s.width,h=s.height,cx=w/2;final p=Path();
    final motif=level%4;
    if(owner){p.moveTo(cx,h*.02);p.lineTo(w*.93,h*.18);p.lineTo(w*.86,h*.68);p.lineTo(cx,h*.99);p.lineTo(w*.14,h*.68);p.lineTo(w*.07,h*.18);}
    else if(motif==0){p.moveTo(cx,h*.025);p.lineTo(w*.91,h*.19);p.lineTo(w*.82,h*.68);p.lineTo(cx,h*.96);p.lineTo(w*.18,h*.68);p.lineTo(w*.09,h*.19);}
    else if(motif==1){p.moveTo(cx,h*.04);p.lineTo(w*.88,h*.12);p.lineTo(w*.96,h*.46);p.lineTo(w*.72,h*.82);p.lineTo(cx,h*.97);p.lineTo(w*.28,h*.82);p.lineTo(w*.04,h*.46);p.lineTo(w*.12,h*.12);}
    else if(motif==2){p.moveTo(cx,h*.02);p.lineTo(w*.8,h*.12);p.lineTo(w*.96,h*.36);p.lineTo(w*.84,h*.76);p.lineTo(cx,h*.98);p.lineTo(w*.16,h*.76);p.lineTo(w*.04,h*.36);p.lineTo(w*.2,h*.12);}
    else{p.moveTo(cx,h*.02);p.lineTo(w*.94,h*.27);p.lineTo(w*.78,h*.78);p.lineTo(cx,h*.96);p.lineTo(w*.22,h*.78);p.lineTo(w*.06,h*.27);}
    p.close();
    final shadow=Paint()..color=Colors.black87..maskFilter=const MaskFilter.blur(BlurStyle.normal,7);
    canvas.save();canvas.translate(2,7);canvas.drawPath(p,shadow);canvas.restore();
    final side=Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
      colors:[colors.last,const Color(0xFF05070D)]).createShader(Offset(0,0)&s);
    canvas.drawPath(p.shift(const Offset(0,5)),side);
    canvas.drawPath(p,Paint()..shader=LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
      colors:[colors[1],colors[0],colors.last,const Color(0xFF090D18)],stops:const[0,.28,.68,1]).createShader(Offset.zero&s));
    canvas.drawPath(p,Paint()..style=PaintingStyle.stroke..strokeWidth=owner?3:2
      ..shader=LinearGradient(colors:[Colors.white,colors[1],colors.last,colors[0]]).createShader(Offset.zero&s));
    final sheen=Rect.fromLTWH(w*(shine*1.5-.25),0,w*.2,h);canvas.save();canvas.clipPath(p);
    canvas.drawRect(sheen,Paint()..shader=LinearGradient(colors:[Colors.transparent,Colors.white54,Colors.transparent]).createShader(sheen));canvas.restore();
    final inner=Rect.fromCenter(center:Offset(cx,h*.51),width:w*.55,height:h*.58);
    canvas.drawOval(inner,Paint()..style=PaintingStyle.stroke..strokeWidth=1
      ..color=Colors.white.withOpacity(.24));
    final etch=Paint()..style=PaintingStyle.stroke..strokeWidth=1.1
      ..color=colors[1].withOpacity(.85);
    for(var i=0;i<3+(tier%4);i++){
      final y=h*(.28+i*.105);
      canvas.drawLine(Offset(w*.2,y),Offset(w*.8,y),etch);
    }
    final dots=Paint()..color=Colors.white.withOpacity(.92);
    for(final q in [Offset(w*.25,h*.34),Offset(w*.75,h*.34),Offset(cx,h*.18),Offset(w*.3,h*.7),Offset(w*.7,h*.7)])canvas.drawCircle(q,owner?2.2:1.4,dots);
    final gem=Path()..moveTo(cx,h*.12)..lineTo(w*.57,h*.2)..lineTo(cx,h*.29)..lineTo(w*.43,h*.2)..close();
    canvas.drawPath(gem,Paint()..shader=LinearGradient(colors:[Colors.white,colors[1],colors[0]]).createShader(Offset.zero&s));
    canvas.drawPath(gem,Paint()..style=PaintingStyle.stroke..strokeWidth=.7..color=Colors.white);
    final glint=Paint()..color=Colors.white.withOpacity(.55+.35*math.sin(shine*math.pi*2).abs())..maskFilter=const MaskFilter.blur(BlurStyle.normal,3);
    canvas.drawCircle(Offset(w*(.22+(.56*shine)),h*.12),owner?2.5:1.6,glint);
  }
  @override bool shouldRepaint(covariant _EmblemPainter old)=>old.shine!=shine||old.tier!=tier||old.owner!=owner||old.level!=level||old.colors!=colors;
}
