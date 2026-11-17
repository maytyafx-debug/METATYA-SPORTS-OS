import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,

  // Termux/Android: avoid watching dependency, cache, and protected OS paths.
  // Do not ignore /data/** globally because the project itself lives under /data/data.
  webpack(config) {
    const existingIgnored = config.watchOptions?.ignored;
    const ignored = Array.isArray(existingIgnored)
      ? existingIgnored
      : existingIgnored
        ? [existingIgnored]
        : [];

    config.watchOptions = {
      ...config.watchOptions,
      ignored: [
        ...ignored,
        "**/node_modules/**",
        "**/.git/**",
        "**/.next/**",
        "/proc/**",
        "/sys/**",
        "/dev/**",
        "/data/data/com.termux/cache/**",
        "/data/data/com.termux/files/usr/**",
      ],
    };

    return config;
  },
};

export default nextConfig;
