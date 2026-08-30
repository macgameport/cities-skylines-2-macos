/* r8test.c — does DXMT sample single-channel textures correctly?
 *
 * WHY: Steam's CEF renders artwork but ZERO glyphs on every presentation architecture tried
 * (in-process GPU, out-of-process, CAContext remote layer, per-child geometry). Skia uploads glyph
 * masks as single-channel textures (R8_UNORM / A8_UNORM) and samples them; if that path silently
 * yields zero, text disappears while everything else draws. This isolates it with no window, no
 * Steam and no compositor: upload a known pattern, sample it in a pixel shader, read the rendered
 * pixels back, print the numbers.
 *
 * Control is the same test through R8G8B8A8_UNORM. If RGBA passes and R8/A8 come back black, the
 * glyph mystery is a texture-format bug.
 *
 * Build: x86_64-w64-mingw32-gcc r8test.c -o r8test.exe -ld3d11 -ldxgi -ld3dcompiler -ldxguid -luuid
 */
#include <windows.h>
#include <stdio.h>
#include <d3d11.h>
#include <d3dcompiler.h>

#define W 64
#define H 64

static const char *SHADER =
"Texture2D tex : register(t0);\n"
"SamplerState smp : register(s0);\n"
"float4 vs(uint id : SV_VertexID) : SV_Position {\n"
"  float2 p = float2((id << 1) & 2, id & 2);\n"
"  return float4(p * float2(2, -2) + float2(-1, 1), 0, 1);\n"
"}\n"
"float4 ps(float4 pos : SV_Position) : SV_Target {\n"
"  float4 t = tex.Load(int3(pos.xy, 0));\n"
"  /* A8_UNORM legitimately returns (0,0,0,A) -- reading .r alone would report a false\n"
"     failure on correct hardware too. Take whichever channel actually carries the data. */\n"
"  float v = max(t.r, t.a);\n"
"  return float4(v, v, v, 1);\n"
"}\n";

static int run(ID3D11Device *dev, ID3D11DeviceContext *ctx, ID3D11VertexShader *vs,
               ID3D11PixelShader *ps, DXGI_FORMAT fmt, const char *name, int bytes_per_px)
{
    unsigned char src[W * H * 4];
    int i;
    for (i = 0; i < W * H * bytes_per_px; i++) src[i] = 0xFF;   /* fully "lit" everywhere */

    D3D11_TEXTURE2D_DESC td = {0};
    td.Width = W; td.Height = H; td.MipLevels = 1; td.ArraySize = 1;
    td.Format = fmt; td.SampleDesc.Count = 1;
    td.Usage = D3D11_USAGE_DEFAULT; td.BindFlags = D3D11_BIND_SHADER_RESOURCE;
    D3D11_SUBRESOURCE_DATA sd = { src, W * bytes_per_px, 0 };

    ID3D11Texture2D *tex = NULL;
    HRESULT hr = dev->lpVtbl->CreateTexture2D(dev, &td, &sd, &tex);
    if (FAILED(hr)) { printf("  %-18s CreateTexture2D FAILED hr=0x%08lX\n", name, (unsigned long)hr); return 0; }

    ID3D11ShaderResourceView *srv = NULL;
    hr = dev->lpVtbl->CreateShaderResourceView(dev, (ID3D11Resource *)tex, NULL, &srv);
    if (FAILED(hr)) { printf("  %-18s CreateSRV FAILED hr=0x%08lX\n", name, (unsigned long)hr); return 0; }

    /* render target */
    D3D11_TEXTURE2D_DESC rd = td;
    rd.Format = DXGI_FORMAT_R8G8B8A8_UNORM; rd.BindFlags = D3D11_BIND_RENDER_TARGET;
    ID3D11Texture2D *rt = NULL;
    dev->lpVtbl->CreateTexture2D(dev, &rd, NULL, &rt);
    ID3D11RenderTargetView *rtv = NULL;
    dev->lpVtbl->CreateRenderTargetView(dev, (ID3D11Resource *)rt, NULL, &rtv);

    float clear[4] = {0, 0, 0, 1};
    ctx->lpVtbl->ClearRenderTargetView(ctx, rtv, clear);
    D3D11_VIEWPORT vp = {0, 0, W, H, 0, 1};
    ctx->lpVtbl->RSSetViewports(ctx, 1, &vp);
    ctx->lpVtbl->OMSetRenderTargets(ctx, 1, &rtv, NULL);
    ctx->lpVtbl->VSSetShader(ctx, vs, NULL, 0);
    ctx->lpVtbl->PSSetShader(ctx, ps, NULL, 0);
    ctx->lpVtbl->PSSetShaderResources(ctx, 0, 1, &srv);
    ctx->lpVtbl->IASetPrimitiveTopology(ctx, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    ctx->lpVtbl->Draw(ctx, 3, 0);

    /* read back */
    D3D11_TEXTURE2D_DESC stg = rd;
    stg.Usage = D3D11_USAGE_STAGING; stg.BindFlags = 0;
    stg.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    ID3D11Texture2D *st = NULL;
    dev->lpVtbl->CreateTexture2D(dev, &stg, NULL, &st);
    ctx->lpVtbl->CopyResource(ctx, (ID3D11Resource *)st, (ID3D11Resource *)rt);

    D3D11_MAPPED_SUBRESOURCE m;
    hr = ctx->lpVtbl->Map(ctx, (ID3D11Resource *)st, 0, D3D11_MAP_READ, 0, &m);
    if (FAILED(hr)) { printf("  %-18s Map FAILED hr=0x%08lX\n", name, (unsigned long)hr); return 0; }
    unsigned char *px = (unsigned char *)m.pData;
    unsigned char c = px[(H / 2) * m.RowPitch + (W / 2) * 4];
    unsigned char a = px[0], b = px[(H - 1) * m.RowPitch + (W - 1) * 4];
    ctx->lpVtbl->Unmap(ctx, (ID3D11Resource *)st, 0);

    printf("  %-18s centre=%3u  topleft=%3u  bottomright=%3u   %s\n", name, c, a, b,
           (c > 200) ? "OK  (texture sampled)" : "*** BLACK -- sampling produced nothing ***");
    return c > 200;
}

/* Allocate the texture EMPTY, then fill it after the fact -- UpdateSubresource on a DEFAULT
 * texture (mode 0) or Map(WRITE_DISCARD) on a DYNAMIC one (mode 1). */
static int run_upload(ID3D11Device *dev, ID3D11DeviceContext *ctx, ID3D11VertexShader *vs,
                      ID3D11PixelShader *ps, DXGI_FORMAT fmt, const char *name, int dynamic)
{
    unsigned char row[W];
    int i;
    for (i = 0; i < W; i++) row[i] = 0xFF;

    D3D11_TEXTURE2D_DESC td = {0};
    td.Width = W; td.Height = H; td.MipLevels = 1; td.ArraySize = 1;
    td.Format = fmt; td.SampleDesc.Count = 1;
    td.BindFlags = D3D11_BIND_SHADER_RESOURCE;
    td.Usage = dynamic ? D3D11_USAGE_DYNAMIC : D3D11_USAGE_DEFAULT;
    td.CPUAccessFlags = dynamic ? D3D11_CPU_ACCESS_WRITE : 0;

    ID3D11Texture2D *tex = NULL;
    HRESULT hr = dev->lpVtbl->CreateTexture2D(dev, &td, NULL, &tex);
    if (FAILED(hr)) { printf("  %-22s CreateTexture2D FAILED hr=0x%08lX\n", name, (unsigned long)hr); return 0; }

    if (dynamic)
    {
        D3D11_MAPPED_SUBRESOURCE m;
        hr = ctx->lpVtbl->Map(ctx, (ID3D11Resource *)tex, 0, D3D11_MAP_WRITE_DISCARD, 0, &m);
        if (FAILED(hr)) { printf("  %-22s Map FAILED hr=0x%08lX\n", name, (unsigned long)hr); return 0; }
        for (i = 0; i < H; i++) memcpy((unsigned char *)m.pData + i * m.RowPitch, row, W);
        ctx->lpVtbl->Unmap(ctx, (ID3D11Resource *)tex, 0);
    }
    else
    {
        /* fill it a strip at a time, the way an atlas grows */
        for (i = 0; i < H; i++)
        {
            D3D11_BOX box = { 0, i, 0, W, i + 1, 1 };
            ctx->lpVtbl->UpdateSubresource(ctx, (ID3D11Resource *)tex, 0, &box, row, W, 0);
        }
    }

    ID3D11ShaderResourceView *srv = NULL;
    hr = dev->lpVtbl->CreateShaderResourceView(dev, (ID3D11Resource *)tex, NULL, &srv);
    if (FAILED(hr)) { printf("  %-22s CreateSRV FAILED hr=0x%08lX\n", name, (unsigned long)hr); return 0; }

    D3D11_TEXTURE2D_DESC rd = {0};
    rd.Width = W; rd.Height = H; rd.MipLevels = 1; rd.ArraySize = 1;
    rd.Format = DXGI_FORMAT_R8G8B8A8_UNORM; rd.SampleDesc.Count = 1;
    rd.Usage = D3D11_USAGE_DEFAULT; rd.BindFlags = D3D11_BIND_RENDER_TARGET;
    ID3D11Texture2D *rt = NULL; dev->lpVtbl->CreateTexture2D(dev, &rd, NULL, &rt);
    ID3D11RenderTargetView *rtv = NULL; dev->lpVtbl->CreateRenderTargetView(dev, (ID3D11Resource *)rt, NULL, &rtv);

    float clear[4] = {0, 0, 0, 1};
    ctx->lpVtbl->ClearRenderTargetView(ctx, rtv, clear);
    D3D11_VIEWPORT vp = {0, 0, W, H, 0, 1};
    ctx->lpVtbl->RSSetViewports(ctx, 1, &vp);
    ctx->lpVtbl->OMSetRenderTargets(ctx, 1, &rtv, NULL);
    ctx->lpVtbl->VSSetShader(ctx, vs, NULL, 0);
    ctx->lpVtbl->PSSetShader(ctx, ps, NULL, 0);
    ctx->lpVtbl->PSSetShaderResources(ctx, 0, 1, &srv);
    ctx->lpVtbl->IASetPrimitiveTopology(ctx, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    ctx->lpVtbl->Draw(ctx, 3, 0);

    D3D11_TEXTURE2D_DESC stg = rd;
    stg.Usage = D3D11_USAGE_STAGING; stg.BindFlags = 0; stg.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    ID3D11Texture2D *st = NULL; dev->lpVtbl->CreateTexture2D(dev, &stg, NULL, &st);
    ctx->lpVtbl->CopyResource(ctx, (ID3D11Resource *)st, (ID3D11Resource *)rt);

    D3D11_MAPPED_SUBRESOURCE m2;
    hr = ctx->lpVtbl->Map(ctx, (ID3D11Resource *)st, 0, D3D11_MAP_READ, 0, &m2);
    if (FAILED(hr)) { printf("  %-22s readback Map FAILED hr=0x%08lX\n", name, (unsigned long)hr); return 0; }
    unsigned char c = ((unsigned char *)m2.pData)[(H / 2) * m2.RowPitch + (W / 2) * 4];
    ctx->lpVtbl->Unmap(ctx, (ID3D11Resource *)st, 0);

    printf("  %-22s centre=%3u   %s\n", name, c,
           (c > 200) ? "OK" : "*** BLACK -- upload path produced nothing ***");
    return c > 200;
}

int main(void)
{
    ID3D11Device *dev = NULL; ID3D11DeviceContext *ctx = NULL;
    D3D_FEATURE_LEVEL fl;
    HRESULT hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, NULL, 0,
                                   D3D11_SDK_VERSION, &dev, &fl, &ctx);
    if (FAILED(hr)) { printf("D3D11CreateDevice FAILED hr=0x%08lX\n", (unsigned long)hr); return 1; }
    printf("device OK, feature level 0x%04X\n", (unsigned)fl);

    ID3DBlob *vsb = NULL, *psb = NULL, *err = NULL;
    if (FAILED(D3DCompile(SHADER, strlen(SHADER), NULL, NULL, NULL, "vs", "vs_4_0", 0, 0, &vsb, &err)) ||
        FAILED(D3DCompile(SHADER, strlen(SHADER), NULL, NULL, NULL, "ps", "ps_4_0", 0, 0, &psb, &err)))
    { printf("shader compile FAILED: %s\n", err ? (char *)err->lpVtbl->GetBufferPointer(err) : "?"); return 1; }

    ID3D11VertexShader *vs = NULL; ID3D11PixelShader *ps = NULL;
    dev->lpVtbl->CreateVertexShader(dev, vsb->lpVtbl->GetBufferPointer(vsb), vsb->lpVtbl->GetBufferSize(vsb), NULL, &vs);
    dev->lpVtbl->CreatePixelShader(dev, psb->lpVtbl->GetBufferPointer(psb), psb->lpVtbl->GetBufferSize(psb), NULL, &ps);

    printf("A. immutable initial data:\n");
    run(dev, ctx, vs, ps, DXGI_FORMAT_R8G8B8A8_UNORM, "R8G8B8A8 (control)", 4);
    run(dev, ctx, vs, ps, DXGI_FORMAT_R8_UNORM,       "R8_UNORM (glyphs)",  1);
    run(dev, ctx, vs, ps, DXGI_FORMAT_A8_UNORM,       "A8_UNORM (glyphs)",  1);

    /* A glyph atlas is not created full -- it is allocated empty and filled incrementally, which is
     * a different code path from initial data. Model both ways Skia does it. */
    printf("B. incremental upload (how a glyph atlas is actually filled):\n");
    run_upload(dev, ctx, vs, ps, DXGI_FORMAT_R8_UNORM, "R8 UpdateSubresource", 0);
    run_upload(dev, ctx, vs, ps, DXGI_FORMAT_R8_UNORM, "R8 Map/DISCARD",       1);
    run_upload(dev, ctx, vs, ps, DXGI_FORMAT_A8_UNORM, "A8 UpdateSubresource", 0);
    return 0;
}
