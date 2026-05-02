import { DEMO_USER_ID } from "./store";

const DEVICE_ID_HEADER = "x-device-id";
const SAFE_DEVICE_ID = /^[a-zA-Z0-9._:-]{8,128}$/;

export function getRequestUserId(request: Request): string {
  const raw = request.headers.get(DEVICE_ID_HEADER)?.trim();
  if (!raw || !SAFE_DEVICE_ID.test(raw)) {
    return DEMO_USER_ID;
  }
  return `device:${raw}`;
}
