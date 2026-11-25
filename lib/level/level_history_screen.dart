import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LevelHistoryScreen extends StatefulWidget {
  const LevelHistoryScreen({super.key});
  @override
  State<LevelHistoryScreen> createState() => _LevelHistoryScreenState();
}

class _LevelHistoryScreenState extends State<LevelHistoryScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  late Future<_LevelData> _future;
  @override
  void initState() { super.initState(); _future = _load(); }

  Future<_LevelData> _load() async {
    final v = await Future.wait<dynamic>([
      _db.rpc('zoonl_my_level'),
      _db.rpc('zoonl_my_lifetime_gift_exp'),
      _db.from('wealth_levels').select('level,tier_bracket,tier_name,title,required_exp,badge_gradient,badge_border,badge_glow,chat_ribbon_theme,chat_ribbon_bg,chat_ribbon_border,chat_ribbon_shadow,unlocked_perk,is_milestone').order('level'),
      _db.from('gift_sends').select('id,gift_id,quantity,total_coins,created_at').order('created_at', ascending: false).limit(100),
    ]);
    return _LevelData(
      (v[0] as num? ?? 1).toInt().clamp(1,100),
      (v[1] as num? ?? 0).toInt(),
      (v[2] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList(),
      (v[3] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList(),
    );
  }

  List<Color> _colors(String? raw, {List<Color>? fallback}) {
    final found = RegExp(r'#[0-9a-fA-F]{6}').allMatches(raw ?? '')
      .map((m)=>Color(0xFF000000 | int.parse(m.group(0)!.substring(1),radix:16))).toList();
    return found.length >= 2 ? found : (fallback ?? const [Color(0xFF7650A8),Color(0xFF302044)]);
  }

  Color _border(String? raw) {
    final m=RegExp(r'#[0-9a-fA-F]{6}').firstMatch(raw??'');
    return m==null ? const Color(0xFFD6B46A) : Color(0xFF000000|int.parse(m.group(0)!.substring(1),radix:16));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080611),
    appBar: AppBar(
      backgroundColor: const Color(0xFF100C1D),
      title: const Text('ZOONL WEALTH LEVELS',style:TextStyle(color:Color(0xFFE6C47A),fontSize:15,fontWeight:FontWeight.w900)),
      actions:[IconButton(onPressed:()=>setState(()=>_future=_load()),icon:const Icon(Icons.refresh))],
    ),
    body:FutureBuilder<_LevelData>(
      future:_future,
      builder:(context,s){
        if(s.connectionState!=ConnectionState.done) return const Center(child:CircularProgressIndicator());
        if(s.hasError) return Center(child:Text('Level data load failed: ${s.error}',style:const TextStyle(color:Colors.white70)));
        final d=s.data!;
        if(d.levels.length<100) return Center(child:Text('Expected 100 levels, loaded ${d.levels.length}.',style:const TextStyle(color:Colors.white70)));
        final current=d.levels[d.level-1];
        final next=d.level<100?d.levels[d.level]:null;
        final nextExp=(next?['required_exp'] as num?)?.toInt()??d.exp;
        final currentExp=(current['required_exp'] as num?)?.toInt()??0;
        final span=nextExp-currentExp;
        final progress=d.level==100?1.0:(span<=0?0.0:((d.exp-currentExp)/span).clamp(0.0,1.0).toDouble());
        const ranges=[ [1,20],[21,40],[41,60],[61,80],[81,100] ];
        return RefreshIndicator(
          onRefresh:()async{setState(()=>_future=_load());await _future;},
          child:ListView(
            padding:const EdgeInsets.fromLTRB(14,14,14,28),
            children:[
              _currentCard(d,current,progress,nextExp),
              const SizedBox(height:20),
              const Text('LEVEL COLLECTION',style:TextStyle(color:Color(0xFFE6C47A),fontWeight:FontWeight.w900,letterSpacing:1.1)),
              const SizedBox(height:10),
              for(final range in ranges)...[
                _sectionHeader(range[0],range[1]),
                const SizedBox(height:8),
                for(final row in d.levels.where((x){final n=(x['level'] as num).toInt();return n>=range[0]&&n<=range[1];}))
                  _levelTile(row,d.level),
                const SizedBox(height:13),
              ],
              const Divider(color:Colors.white24,height:25),
              const Text('GIFT / WEALTH EXP HISTORY',style:TextStyle(color:Color(0xFFE6C47A),fontWeight:FontWeight.w900,letterSpacing:1)),
              const SizedBox(height:8),
              if(d.history.isEmpty)
                const Padding(padding:EdgeInsets.all(18),child:Text('No gift transactions recorded yet.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white54)))
              else for(final item in d.history)
                Card(color:const Color(0xFF171126),child:ListTile(
                  leading:const Icon(Icons.card_giftcard,color:Color(0xFFE6C47A)),
                  title:Text('Gift sent • ${item['quantity']??1} item(s)',style:const TextStyle(color:Colors.white)),
                  subtitle:Text(DateTime.parse(item['created_at'].toString()).toLocal().toString().substring(0,16),style:const TextStyle(color:Colors.white54)),
                  trailing:Text('${item['total_coins']??0} coins',style:const TextStyle(color:Color(0xFFE6C47A),fontWeight:FontWeight.w900)),
                )),
            ],
          ),
        );
      },
    ),
  );

  Widget _currentCard(_LevelData d,Map<String,dynamic> row,double progress,int nextExp){
    final palette=_colors(row['badge_gradient']?.toString());
    return Container(
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:palette),
        borderRadius:BorderRadius.circular(18),
        border:Border.all(color:_border(row['badge_border']?.toString()),width:1.6),
        boxShadow:[BoxShadow(color:_border(row['badge_border']?.toString()).withOpacity(.35),blurRadius:20)],
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('YOUR CURRENT LEVEL',style:TextStyle(color:Colors.white70,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1)),
        const SizedBox(height:9),
        Row(children:[
          _levelPill(d.level,row,width:104,height:43),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text((row['title']??'').toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:15)),
            Text('${d.exp} WEALTH EXP',style:const TextStyle(color:Colors.white70,fontSize:11)),
          ])),
        ]),
        const SizedBox(height:12),
        ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:progress,minHeight:7,backgroundColor:Colors.black38,valueColor:const AlwaysStoppedAnimation(Color(0xFFFFE9A5)))),
        const SizedBox(height:6),
        Text(d.level==100?'MAXIMUM LEVEL': '${(nextExp-d.exp).clamp(0,nextExp)} EXP TO LEVEL ${d.level+1}',style:const TextStyle(color:Colors.white70,fontSize:10,fontWeight:FontWeight.w700)),
      ]),
    );
  }

  Widget _sectionHeader(int from,int to)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:13,vertical:10),
    decoration:BoxDecoration(color:const Color(0xFF191126),borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFF72528E))),
    child:Row(children:[
      const Icon(Icons.folder_special,color:Color(0xFFE6C47A),size:18),
      const SizedBox(width:8),
      Text('LEVEL $from - $to',style:const TextStyle(color:Color(0xFFFFE4A0),fontWeight:FontWeight.w900,letterSpacing:.8)),
      const Spacer(),
      Text('20 BADGES',style:TextStyle(color:Colors.white.withOpacity(.55),fontSize:9,fontWeight:FontWeight.w800)),
    ]),
  );

  Widget _levelTile(Map<String,dynamic> row,int current){
    final n=(row['level'] as num).toInt();
    final unlocked=n<=current;
    final ribbon=_colors(row['chat_ribbon_bg']?.toString(),fallback:_colors(row['badge_gradient']?.toString()));
    final ribbonBorder=_border(row['chat_ribbon_border']?.toString());
    return Container(
      margin:const EdgeInsets.only(bottom:7),
      padding:const EdgeInsets.all(9),
      decoration:BoxDecoration(
        color:const Color(0xFF151020),
        borderRadius:BorderRadius.circular(12),
        border:Border.all(color:unlocked?_border(row['badge_border']?.toString()).withOpacity(.8):Colors.white12),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          _levelPill(n,row,width:76,height:32),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text((row['title']??'LEVEL $n').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:11)),
            Text((row['tier_name']??'').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white54,fontSize:9)),
          ])),
          Icon(unlocked?Icons.lock_open:Icons.lock_outline,color:unlocked?const Color(0xFFE6C47A):Colors.white30,size:17),
        ]),
        const SizedBox(height:7),
        Container(
          width:double.infinity,
          padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
          decoration:BoxDecoration(
            gradient:LinearGradient(colors:ribbon),
            borderRadius:BorderRadius.circular(7),
            border:Border.all(color:ribbonBorder,width:1),
            boxShadow:[BoxShadow(color:ribbonBorder.withOpacity(.2),blurRadius:8)],
          ),
          child:Row(children:[
            const Icon(Icons.chat_bubble,size:11,color:Colors.white),
            const SizedBox(width:6),
            Expanded(child:Text('CHAT RIBBON • ${row['chat_ribbon_theme']??'Level Chat Style'}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))),
            Text('LV $n',style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900)),
          ]),
        ),
        const SizedBox(height:5),
        Row(children:[
          Expanded(child:Text('EXP: ${row['required_exp']??0}',style:const TextStyle(color:Colors.white54,fontSize:9))),
          if((row['unlocked_perk']??'').toString().isNotEmpty)
            Expanded(child:Text(row['unlocked_perk'].toString(),maxLines:1,textAlign:TextAlign.end,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Color(0xFFE6C47A),fontSize:9))),
        ]),
      ]),
    );
  }

  Widget _levelPill(int n,Map<String,dynamic> row,{double width=80,double height=34}){
    final colors=_colors(row['badge_gradient']?.toString());
    return Container(
      width:width,height:height,
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:colors),
        borderRadius:BorderRadius.circular(height/2),
        border:Border.all(color:_border(row['badge_border']?.toString()),width:1.4),
        boxShadow:[BoxShadow(color:_border(row['badge_border']?.toString()).withOpacity(.35),blurRadius:8)],
      ),
      alignment:Alignment.center,
      child:Text('LV$n',style:TextStyle(color:Colors.white,fontSize:height*.36,fontWeight:FontWeight.w900,letterSpacing:.4,shadows:const[Shadow(color:Colors.black87,blurRadius:3)])),
    );
  }
}

class _LevelData{
  final int level,exp;
  final List<Map<String,dynamic>> levels,history;
  const _LevelData(this.level,this.exp,this.levels,this.history);
}
