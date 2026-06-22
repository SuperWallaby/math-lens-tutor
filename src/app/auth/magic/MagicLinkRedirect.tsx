"use client";

import { useEffect } from "react";

export function MagicLinkRedirect({ appLink }: { appLink: string }) {
  useEffect(() => {
    if (!appLink) return;
    window.location.href = appLink;
  }, [appLink]);

  return null;
}
