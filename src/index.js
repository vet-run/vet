// SPDX-FileCopyrightText: 2025-present Artem Lykhvar and contributors
//
// SPDX-License-Identifier: MIT

const GITHUB_REPO = "vet-run/vet";
const PROMO_PAGE_URL = `https://raw.githubusercontent.com/${GITHUB_REPO}/main/public/index.html`;
const INSTALL_SCRIPT_URL = `https://raw.githubusercontent.com/${GITHUB_REPO}/main/scripts/install.sh`;

export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);

        if (url.pathname === "/install.sh") {
            const scriptResponse = await fetch(INSTALL_SCRIPT_URL);
            return new Response(scriptResponse.body, {
                headers: { "Content-Type": "text/plain; charset=utf-8" },
                status: scriptResponse.status,
            });
        }

        if (url.pathname === "/") {
            const promoResponse = await fetch(PROMO_PAGE_URL);
            return new Response(promoResponse.body, {
                headers: { "Content-Type": "text/html; charset=utf-8" },
                status: promoResponse.status,
            });
        }

        return new Response("Not Found", { status: 404 });
    },
};
