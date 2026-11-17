import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  const path = request.nextUrl.pathname;
  const response = NextResponse.next({ request });

  // Environment values can contain trailing whitespace or CRLF characters in Termux.
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const key = (
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  )?.trim();

  let parsedUrl: URL | null = null;
  if (url) {
    try {
      parsedUrl = new URL(url);
    } catch {
      parsedUrl = null;
    }
  }

  const validUrl =
    parsedUrl !== null &&
    (parsedUrl.protocol === "http:" || parsedUrl.protocol === "https:") &&
    parsedUrl.hostname.length > 0;

  // Do not let a missing or malformed public configuration crash middleware.
  // Keep /login reachable so the user can see the authentication screen.
  if (!validUrl || !key) {
    if (path !== "/login") {
      return NextResponse.redirect(new URL("/login", request.url));
    }
    return response;
  }

  let supabaseResponse = response;
  const supabase = createServerClient(url!, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(items) {
        items.forEach(({ name, value }) => request.cookies.set(name, value));
        supabaseResponse = NextResponse.next({ request });
        items.forEach(({ name, value, options }) =>
          supabaseResponse.cookies.set(name, value, options),
        );
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (path === "/" && !user) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  if (path === "/login" && user) {
    return NextResponse.redirect(new URL("/", request.url));
  }

  supabaseResponse.headers.set("Cache-Control", "private, no-store");
  return supabaseResponse;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
