import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../dev/agent_debug_log.dart';
import '../theme/app_design_system.dart';
import 'problem_chart.dart';
import 'problem_jsx_graph.dart';

/// visualization_data + legacy chart/jsxGraph 통합 렌더러
class VisualizationView extends StatelessWidget {
  const VisualizationView({
    super.key,
    this.visualizationData,
    this.chart,
    this.jsxGraph,
    this.height = 400,
  });

  final Map<String, dynamic>? visualizationData;
  final Map<String, dynamic>? chart;
  final Map<String, dynamic>? jsxGraph;
  final double height;

  @override
  Widget build(BuildContext context) {
    final viz = _resolveVisualization();
    if (viz == null) return const SizedBox.shrink();

    final caption = (viz['captionKo'] as String?)?.trim();
    final child = _buildEngineWidget(viz);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption != null && caption.isNotEmpty) ...[
          Text(
            caption,
            style: const TextStyle(color: AppColors.textSub, fontSize: 13),
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            color: AppColors.surfaceElevated,
            child: child,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic>? _resolveVisualization() {
    final raw = visualizationData;
    if (raw != null && raw.isNotEmpty) {
      final data = (raw['data'] as Map?)?.cast<String, dynamic>() ?? {};
      return {
        'type': raw['type'],
        'engine': raw['engine'],
        'data': data,
        'captionKo': data['captionKo'],
      };
    }
    if (chart != null) {
      return {
        'type': 'chart',
        'engine': 'chartjs',
        'data': chart!,
      };
    }
    if (jsxDiagramShows(jsxGraph)) {
      return {
        'type': 'geometry',
        'engine': 'jsxgraph',
        'data': {'legacyJsxGraph': jsxGraph},
      };
    }
    return null;
  }

  Widget _buildEngineWidget(Map<String, dynamic> viz) {
    final type = viz['type'] as String? ?? '';
    final engine = viz['engine'] as String? ?? '';
    final data = (viz['data'] as Map?)?.cast<String, dynamic>() ?? {};

    // #region agent log
    agentDebugLog(
      location: 'visualization_view.dart:_buildEngineWidget',
      message: 'resolved visualization engine',
      hypothesisId: 'A',
      data: {
        'type': type,
        'engine': engine,
        'dataKeys': data.keys.toList(),
        'expression': data['expression'],
        'expressions': data['expressions'],
        'elementCount': data['elements'] is List
            ? (data['elements'] as List).length
            : null,
      },
    );
    // #endregion

    if (engine == 'chartjs' || type == 'chart') {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: ProblemChart(chart: data),
      );
    }

    if (engine == 'desmos' || type == 'function_graph') {
      return SizedBox(
        height: height,
        child: _DesmosWebView(data: data),
      );
    }

    if (engine == 'jsxgraph' ||
        type == 'geometry' ||
        type == 'coordinate') {
      final spec = _jsxSpecFromData(data);
      if (spec == null) return const SizedBox.shrink();
      return ProblemJsxGraph(spec: spec);
    }

    return const SizedBox.shrink();
  }

  Map<String, dynamic>? _jsxSpecFromData(Map<String, dynamic> data) {
    final legacy = data['legacyJsxGraph'];
    if (legacy is Map) return legacy.cast<String, dynamic>();

    final points = data['points'];
    if (points is Map) {
      return _geometryPointsToJsx(data);
    }

    if (data['elements'] is List || data['board'] is Map) {
      return {
        'diagramNeeded': true,
        'captionKo': data['captionKo'],
        'board': data['board'] ??
            {
              'boundingbox': [-6, 12, 12, -6],
              'axis': true,
              'keepaspectratio': true,
            },
        'elements': data['elements'] ?? [],
      };
    }

    return null;
  }

  Map<String, dynamic> _geometryPointsToJsx(Map<String, dynamic> data) {
    final points = (data['points'] as Map).cast<String, dynamic>();
    final showLabels = data['showLabels'] != false;
    final elements = <Map<String, dynamic>>[];
    final ids = <String>[];

    for (final entry in points.entries) {
      final coord = entry.value;
      if (coord is! List || coord.length < 2) continue;
      ids.add(entry.key);
      elements.add({
        'elType': 'point',
        'id': entry.key,
        'coord': [coord[0], coord[1]],
        'attrs': {
          'name': showLabels ? entry.key : '',
          'fixed': true,
          'size': 3,
        },
      });
    }

    final shape = data['shape'] as String? ?? 'polygon';
    if (shape == 'triangle' && ids.length >= 3) {
      elements.add({
        'elType': 'polygon',
        'parents': ids.take(3).toList(),
        'attrs': {
          'fillColor': '#e8f4fc',
          'borders': {'strokeColor': '#2563eb'},
        },
      });
    } else if (ids.length >= 3) {
      elements.add({
        'elType': 'polygon',
        'parents': ids,
        'attrs': {
          'fillColor': '#e8f4fc',
          'borders': {'strokeColor': '#2563eb'},
        },
      });
    }

    return {
      'diagramNeeded': true,
      'captionKo': data['captionKo'],
      'board': data['board'] ??
          {
            'boundingbox': _boundingBoxFromPoints(points),
            'axis': true,
            'keepaspectratio': true,
          },
      'elements': elements,
    };
  }

  List<double> _boundingBoxFromPoints(Map<String, dynamic> points) {
    final coords = points.values
        .whereType<List>()
        .map((c) => [c[0] as num, c[1] as num])
        .toList();
    if (coords.isEmpty) return [-6, 12, 12, -6];
    final xs = coords.map((c) => c[0].toDouble());
    final ys = coords.map((c) => c[1].toDouble());
    const pad = 2.0;
    return [
      xs.reduce((a, b) => a < b ? a : b) - pad,
      ys.reduce((a, b) => a > b ? a : b) + pad,
      xs.reduce((a, b) => a > b ? a : b) + pad,
      ys.reduce((a, b) => a < b ? a : b) - pad,
    ];
  }
}

class _DesmosWebView extends StatefulWidget {
  const _DesmosWebView({required this.data});

  final Map<String, dynamic> data;

  @override
  State<_DesmosWebView> createState() => _DesmosWebViewState();
}

class _DesmosWebViewState extends State<_DesmosWebView> {
  late final WebViewController _controller;

  void _onAgentDebugMessage(JavaScriptMessage message) {
    try {
      final parsed = jsonDecode(message.message) as Map<String, dynamic>;
      agentDebugLog(
        location: 'visualization_view.dart:desmos-webview',
        message: parsed['message'] as String? ?? 'desmos event',
        hypothesisId: parsed['hypothesisId'] as String? ?? 'E',
        data: (parsed['data'] as Map?)?.cast<String, dynamic>(),
      );
    } catch (_) {
      agentDebugLog(
        location: 'visualization_view.dart:desmos-webview',
        message: message.message,
        hypothesisId: 'E',
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
      ..loadHtmlString(_buildDesmosHtml(widget.data));
    // #region agent log
    agentDebugLog(
      location: 'visualization_view.dart:_DesmosWebViewState.initState',
      message: 'loading desmos html',
      hypothesisId: 'B',
      data: {
        'expression': widget.data['expression'],
        'expressions': widget.data['expressions'],
        'xRange': widget.data['xRange'],
        'yRange': widget.data['yRange'],
      },
    );
    // #endregion
  }

  @override
  void didUpdateWidget(covariant _DesmosWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _controller.loadHtmlString(_buildDesmosHtml(widget.data));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

String _buildDesmosHtml(Map<String, dynamic> data) {
  const apiKey = String.fromEnvironment(
    'DESMOS_API_KEY',
    defaultValue: 'dcb31709b452b1f69fc8a5890484ff01',
  );
  final payload = base64Encode(utf8.encode(jsonEncode(data)));
  assert(!payload.contains("'"));

  return '''
<!DOCTYPE html>
<html><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://www.desmos.com/api/v1.9/calculator.js?apiKey=$apiKey"></script>
<style>html,body{margin:0;height:100%;}#calculator{width:100%;height:100%;}</style>
</head><body><div id="calculator"></div>
<script>(function(){
function agentLog(message,hypothesisId,data){
  try{AgentDebug.postMessage(JSON.stringify({message:message,hypothesisId:hypothesisId,data:data||{}}));}catch(e){}
}
var SAFE='$payload';
function decodeB64Utf8(b64){
  var bin=atob(b64);
  var u=new Uint8Array(bin.length);
  for(var i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);
  return new TextDecoder('utf-8').decode(u);
}
var data;
try{data=JSON.parse(decodeB64Utf8(SAFE));}catch(e){
  agentLog('desmos json parse failed','B',{error:String(e)});
  return;
}
agentLog('desmos data parsed','B',{expression:data.expression,expressions:data.expressions,xRange:data.xRange,yRange:data.yRange});
if(typeof Desmos==='undefined'){
  agentLog('Desmos global missing','C',{});
  return;
}
var elt=document.getElementById('calculator');
var calc=Desmos.GraphingCalculator(elt,{expressions:false,settingsMenu:false,zoomButtons:true});
var expr=data.expression||'y=x^2';
var applied=[];
if(Array.isArray(data.expressions)){
  data.expressions.forEach(function(latex,i){
    calc.setExpression({id:'e'+i,latex:latex});
    applied.push(latex);
  });
}else{
  calc.setExpression({id:'main',latex:expr});
  applied.push(expr);
}
agentLog('desmos expressions applied','E',{applied:applied,desmosReady:true});
if(data.xRange&&data.yRange){
  calc.setMathBounds({left:data.xRange[0],right:data.xRange[1],bottom:data.yRange[0],top:data.yRange[1]});
  agentLog('desmos bounds set','D',{left:data.xRange[0],right:data.xRange[1],bottom:data.yRange[0],top:data.yRange[1]});
}
})();</script></body></html>''';
}

bool visualizationShows({
  Map<String, dynamic>? visualizationData,
  Map<String, dynamic>? chart,
  Map<String, dynamic>? jsxGraph,
}) {
  if (visualizationData != null && visualizationData.isNotEmpty) {
    final type = visualizationData['type'];
    if (type != null && '$type'.isNotEmpty) return true;
  }
  if (chart != null && chart.isNotEmpty) return true;
  return jsxDiagramShows(jsxGraph);
}
