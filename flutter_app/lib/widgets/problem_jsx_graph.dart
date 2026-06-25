import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../dev/agent_debug_log.dart';

bool jsxDiagramShows(Map<String, dynamic>? jsx) {
  if (jsx == null) return false;
  final dn = jsx['diagramNeeded'];
  return dn == true || dn == 1;
}

String buildProblemJsxGraphHtml(Map<String, dynamic> spec) {
  final b64 =
      base64Encode(utf8.encode(jsonEncode(spec)));
  assert(!b64.contains("'"), 'Unexpected quote in base64');

  return '''
<!DOCTYPE html>
<html><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/jsxgraph@1.12.2/distrib/jsxgraph.css"/>
<script src="https://cdn.jsdelivr.net/npm/jsxgraph@1.12.2/distrib/jsxgraphcore.js"></script>
<style>
  html,body{margin:0;background:#fafafa;}
  #jxgbox{width:100%;height:392px;}
</style></head><body><div id="jxgbox" class="jxgbox"></div>
<script>(function(){
function agentLog(message,hypothesisId,data){
  try{AgentDebug.postMessage(JSON.stringify({message:message,hypothesisId:hypothesisId,data:data||{}}));}catch(e){}
}
var SAFE='$b64';
function decodeB64Utf8(b64){
  var bin=atob(b64);
  var u=new Uint8Array(bin.length);
  for(var i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);
  return new TextDecoder('utf-8').decode(u);
}
var diagram;
try{diagram=JSON.parse(decodeB64Utf8(SAFE));}catch(e){
  agentLog('jsx json parse failed','A',{error:String(e)});
  return;
}
if(!diagram||!diagram.diagramNeeded)return;
var els=diagram.elements||[];
var elTypes=els.map(function(el){return String(el.elType||'');});
agentLog('jsx diagram loaded','A',{elementCount:els.length,elTypes:elTypes});
var bb=(diagram.board&&diagram.board.boundingbox&&diagram.board.boundingbox.length===4)?diagram.board.boundingbox:[-6,12,12,-6];
var board=JXG.JSXGraph.initBoard("jxgbox",{
  boundingbox:bb,
  axis:diagram.board?!!diagram.board.axis:true,
  keepaspectratio:diagram.board?diagram.board.keepaspectratio!==false:true,
  showCopyright:false,
  showNavigation:false,
  resize:{enabled:false}
});
var ALLOW=new Set(["point","segment","line","polygon","circle","arc","sector","angle","text","ticks","grid","midpoint","perpendicular","perpendicularsegment","bisector","glider"]);
var reg={};
var created=0,skipped=0,errors=0;
function res(p){
  if(typeof p==="string"&&reg[p])return reg[p];
  if(Array.isArray(p)&&p.length===2&&typeof p[0]==="number"&&typeof p[1]==="number")return p;
  return p;
}
for(var i=0;i<els.length;i++){
  var el=els[i];
  var t=String(el.elType||"").trim();
  if(!ALLOW.has(t)){skipped++;continue;}
  var ps=el.parents||[];
  if(t==="point"&&el.coord&&ps.length===0)ps=[el.coord];
  var rp=ps.map(res);
  try{
    var o=board.create(t,rp,el.attrs||{});
    if(el.id)reg[String(el.id)]=o;
    created++;
  }catch(err){errors++;}
}
agentLog('jsx elements rendered','A',{created:created,skipped:skipped,errors:errors});
})();</script></body></html>''';
}

class ProblemJsxGraph extends StatefulWidget {
  const ProblemJsxGraph({super.key, required this.spec});

  final Map<String, dynamic> spec;

  @override
  State<ProblemJsxGraph> createState() => _ProblemJsxGraphState();
}

class _ProblemJsxGraphState extends State<ProblemJsxGraph> {
  late final WebViewController _controller;

  void _onAgentDebugMessage(JavaScriptMessage message) {
    try {
      final parsed = jsonDecode(message.message) as Map<String, dynamic>;
      agentDebugLog(
        location: 'problem_jsx_graph.dart:jsx-webview',
        message: parsed['message'] as String? ?? 'jsx event',
        hypothesisId: parsed['hypothesisId'] as String? ?? 'A',
        data: (parsed['data'] as Map?)?.cast<String, dynamic>(),
      );
    } catch (_) {
      agentDebugLog(
        location: 'problem_jsx_graph.dart:jsx-webview',
        message: message.message,
        hypothesisId: 'A',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'AgentDebug',
        onMessageReceived: _onAgentDebugMessage,
      )
      ..loadHtmlString(buildProblemJsxGraphHtml(widget.spec));
  }

  @override
  void didUpdateWidget(covariant ProblemJsxGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec != widget.spec) {
      _controller.loadHtmlString(buildProblemJsxGraphHtml(widget.spec));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 400,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
