export type SkeletonVariant = "default" | "error";

export function Skeleton({
  className = "",
  variant = "default",
  style,
}: {
  className?: string;
  variant?: SkeletonVariant;
  style?: React.CSSProperties;
}) {
  const shimmer =
    variant === "error" ? "skeleton-shimmer-error" : "skeleton-shimmer";

  return (
    <div className={`${shimmer} ${className}`} style={style} aria-hidden />
  );
}
