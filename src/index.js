// SPDX-FileCopyrightText: 2025-present Artem Lykhvar and contributors
//
// SPDX-License-Identifier: MIT

const GITHUB_REPO = "vet-run/vet";
const PROMO_PAGE_URL = `https://raw.githubusercontent.com/${GITHUB_REPO}/main/public/index.html`;
const INSTALL_SCRIPT_URL = `https://github.com/${GITHUB_REPO}/releases/latest/download/install.sh`;
const CACHE_TTL_SECONDS = 900;


export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);

        if (url.pathname === "/install.sh") {
            return handleInstallScriptRequest(request, ctx);
        }

        if (url.pathname === "/") {
            return handlePromoPageRequest(request, ctx);
        }

        return new Response("Not Found", { status: 404 });
    },
};

function handleInstallScriptRequest(request, ctx) {
    const fetcher = () => fetch(INSTALL_SCRIPT_URL);
    return cachedFetch(request, ctx, fetcher, "text/plain; charset=utf-8");
};


function handlePromoPageRequest(request, ctx) {
    const fetcher = () => fetch(PROMO_PAGE_URL);
    return cachedFetch(request, ctx, fetcher, "text/html; charset=utf-8");
};

async function cachedFetch(request, ctx, fetcher, contentType) {
    const cache = caches.default;
    let response = await cache.match(request);

    if (!response) {
        const sourceResponse = await fetcher();

        if (!sourceResponse.ok) {
            return sourceResponse;
        }

        response = new Response(sourceResponse.body, {
            status: sourceResponse.status,
            headers: {
                "Content-Type": contentType,
                "Cache-Control": `s-maxage=${CACHE_TTL_SECONDS}`,
            },
        });

        ctx.waitUntil(cache.put(request, response.clone()));
    }
    return response;
};
