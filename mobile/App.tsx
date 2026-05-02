import Constants from "expo-constants";
import { StatusBar } from "expo-status-bar";
import { useMemo, useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context";
import { WebView } from "react-native-webview";

/** 배포된 Next.js 앱 URL (Vercel 등). 로컬 테스트 시 LAN IP + 포트. */
const WEB_URL =
  process.env.EXPO_PUBLIC_WEB_URL?.trim() ||
  String(Constants.expoConfig?.extra?.webUrl ?? "").trim() ||
  "";

export default function App() {
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [reloadKey, setReloadKey] = useState(0);
  const uri = useMemo(() => WEB_URL, []);

  if (!uri) {
    return (
      <SafeAreaProvider>
        <SafeAreaView style={styles.center}>
          <Text style={styles.title}>웹 주소가 설정되지 않았습니다</Text>
          <Text style={styles.body}>
            mobile/.env 에 EXPO_PUBLIC_WEB_URL 을 넣으세요.{"\n"}
            예: https://your-app.vercel.app
          </Text>
          <StatusBar style="light" />
        </SafeAreaView>
      </SafeAreaProvider>
    );
  }

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.fill} edges={["top"]}>
        <StatusBar style="light" />
        {loading ? (
          <View style={styles.overlay}>
            <ActivityIndicator size="large" color="#60a5fa" />
            <Text style={styles.loadingText}>불러오는 중…</Text>
          </View>
        ) : null}
        {error ? (
          <View style={styles.errorBanner}>
            <Text style={styles.errorText}>{error}</Text>
            <Pressable
              onPress={() => {
                setError(null);
                setLoading(true);
                setReloadKey((k) => k + 1);
              }}
              style={styles.retry}
            >
              <Text style={styles.retryText}>다시 시도</Text>
            </Pressable>
          </View>
        ) : null}
        <WebView
          key={reloadKey}
          source={{ uri }}
          style={styles.webview}
          javaScriptEnabled
          domStorageEnabled
          allowsInlineMediaPlayback
          mediaPlaybackRequiresUserAction={false}
          mixedContentMode="compatibility"
          setSupportMultipleWindows={false}
          onLoadEnd={() => setLoading(false)}
          onError={(e) => {
            setLoading(false);
            setError(
              e.nativeEvent.description ||
                "페이지를 불러오지 못했습니다. 네트워크와 주소를 확인하세요.",
            );
          }}
          onHttpError={(e) => {
            if (e.nativeEvent.statusCode >= 400) {
              setError(`HTTP ${e.nativeEvent.statusCode}`);
            }
          }}
        />
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  fill: {
    flex: 1,
    backgroundColor: "#020617",
  },
  webview: {
    flex: 1,
    backgroundColor: "#020617",
  },
  center: {
    flex: 1,
    backgroundColor: "#020617",
    alignItems: "center",
    justifyContent: "center",
    padding: 24,
  },
  title: {
    color: "#f8fafc",
    fontSize: 18,
    fontWeight: "700",
    marginBottom: 12,
    textAlign: "center",
  },
  body: {
    color: "#94a3b8",
    fontSize: 15,
    lineHeight: 22,
    textAlign: "center",
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#020617",
    zIndex: 2,
  },
  loadingText: {
    marginTop: 12,
    color: "#94a3b8",
    fontSize: 14,
  },
  errorBanner: {
    backgroundColor: "#7f1d1d",
    paddingHorizontal: 12,
    paddingVertical: 8,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 8,
    zIndex: 1,
  },
  errorText: {
    flex: 1,
    color: "#fecaca",
    fontSize: 13,
  },
  retry: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: "#ffffff22",
    borderRadius: 8,
  },
  retryText: {
    color: "#fff",
    fontSize: 13,
    fontWeight: "600",
  },
});
