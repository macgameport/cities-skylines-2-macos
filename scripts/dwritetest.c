/* dwritetest.c — does DirectWrite actually RASTERISE glyphs on this stack?
 *
 * WHY: Steam's CEF draws artwork but zero text on every configuration tried. Fonts ENUMERATE fine
 * here (924 GDI / 204 DirectWrite families, identical to the CrossOver-lineage build that DOES
 * render text) and dwrite.so carries all 56 pFT_* pointers — but nothing has ever checked that a
 * glyph run produces non-empty coverage. This asks DirectWrite for the alpha texture of a real
 * glyph run and sums the bytes. Non-zero => rasterisation works and the fault is higher up in
 * Skia. All-zero => the text never exists as pixels at all, which would explain every observation
 * in the thread at once.
 *
 * Build: x86_64-w64-mingw32-gcc dwritetest.c -o dwritetest.exe -ldwrite -lole32 -luuid
 */
#include <windows.h>
#include <stdio.h>
#include <initguid.h>
#include <dwrite.h>

DEFINE_GUID(IID_IDWriteFactory_, 0xb859ee5a, 0xd838, 0x4b5b, 0xa2,0xe8, 0x1a,0xdc,0x7d,0x93,0xdb,0x48);

static void probe(IDWriteFactory *f, IDWriteFontFace *face, DWRITE_TEXTURE_TYPE tt,
                  DWRITE_RENDERING_MODE rm, const char *label)
{
    UINT32 cps[3] = { 'A', 'B', 'C' };
    UINT16 idx[3] = {0};
    FLOAT adv[3] = {24.0f, 24.0f, 24.0f};
    DWRITE_GLYPH_OFFSET off[3] = {{0,0},{0,0},{0,0}};
    DWRITE_GLYPH_RUN run;
    IDWriteGlyphRunAnalysis *an = NULL;
    RECT r = {0};
    HRESULT hr;

    hr = face->lpVtbl->GetGlyphIndices(face, cps, 3, idx);
    if (FAILED(hr)) { printf("  %-26s GetGlyphIndices FAILED 0x%08lX\n", label, (unsigned long)hr); return; }

    memset(&run, 0, sizeof(run));
    run.fontFace = face; run.fontEmSize = 32.0f; run.glyphCount = 3;
    run.glyphIndices = idx; run.glyphAdvances = adv; run.glyphOffsets = off;

    hr = f->lpVtbl->CreateGlyphRunAnalysis(f, &run, 1.0f, NULL, rm,
                                           DWRITE_MEASURING_MODE_NATURAL, 0.0f, 0.0f, &an);
    if (FAILED(hr)) { printf("  %-26s CreateGlyphRunAnalysis FAILED 0x%08lX\n", label, (unsigned long)hr); return; }

    hr = an->lpVtbl->GetAlphaTextureBounds(an, tt, &r);
    if (FAILED(hr)) { printf("  %-26s GetAlphaTextureBounds FAILED 0x%08lX\n", label, (unsigned long)hr); return; }

    int w = r.right - r.left, h = r.bottom - r.top;
    int bpp = (tt == DWRITE_TEXTURE_CLEARTYPE_3x1) ? 3 : 1;
    if (w <= 0 || h <= 0) { printf("  %-26s EMPTY BOUNDS %dx%d  *** no coverage ***\n", label, w, h); return; }

    UINT32 size = (UINT32)(w * h * bpp);
    BYTE *buf = calloc(1, size);
    hr = an->lpVtbl->CreateAlphaTexture(an, tt, &r, buf, size);
    if (FAILED(hr)) { printf("  %-26s CreateAlphaTexture FAILED 0x%08lX\n", label, (unsigned long)hr); free(buf); return; }

    unsigned long sum = 0; UINT32 i, nz = 0; BYTE mx = 0;
    for (i = 0; i < size; i++) { sum += buf[i]; if (buf[i]) nz++; if (buf[i] > mx) mx = buf[i]; }
    printf("  %-26s bounds %dx%d  nonzero=%u/%u  max=%u  sum=%lu   %s\n",
           label, w, h, nz, size, mx, sum,
           sum ? "OK -- glyphs RASTERISE" : "*** ALL ZERO -- no glyph coverage ***");
    free(buf);
}

int main(void)
{
    IDWriteFactory *f = NULL;
    IDWriteFontCollection *coll = NULL;
    IDWriteFontFamily *fam = NULL;
    IDWriteFont *font = NULL;
    IDWriteFontFace *face = NULL;
    UINT32 index = 0; BOOL exists = FALSE;
    HRESULT hr;

    hr = DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, &IID_IDWriteFactory_, (IUnknown **)&f);
    if (FAILED(hr)) { printf("DWriteCreateFactory FAILED 0x%08lX\n", (unsigned long)hr); return 1; }
    printf("DWriteCreateFactory OK\n");

    hr = f->lpVtbl->GetSystemFontCollection(f, &coll, FALSE);
    if (FAILED(hr)) { printf("GetSystemFontCollection FAILED 0x%08lX\n", (unsigned long)hr); return 1; }
    printf("font families: %u\n", (unsigned)coll->lpVtbl->GetFontFamilyCount(coll));

    coll->lpVtbl->FindFamilyName(coll, L"Arial", &index, &exists);
    if (!exists) { printf("Arial not found, using family 0\n"); index = 0; }
    else printf("using Arial (family %u)\n", (unsigned)index);

    hr = coll->lpVtbl->GetFontFamily(coll, index, &fam);
    if (FAILED(hr)) { printf("GetFontFamily FAILED 0x%08lX\n", (unsigned long)hr); return 1; }
    hr = fam->lpVtbl->GetFirstMatchingFont(fam, DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STRETCH_NORMAL,
                                           DWRITE_FONT_STYLE_NORMAL, &font);
    if (FAILED(hr)) { printf("GetFirstMatchingFont FAILED 0x%08lX\n", (unsigned long)hr); return 1; }
    hr = font->lpVtbl->CreateFontFace(font, &face);
    if (FAILED(hr)) { printf("CreateFontFace FAILED 0x%08lX\n", (unsigned long)hr); return 1; }
    printf("font face OK -- rasterising \"ABC\" at 32px:\n");

    probe(f, face, DWRITE_TEXTURE_ALIASED_1x1,   DWRITE_RENDERING_MODE_ALIASED,           "ALIASED_1x1");
    probe(f, face, DWRITE_TEXTURE_CLEARTYPE_3x1, DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL, "CLEARTYPE_3x1 (natural)");
    probe(f, face, DWRITE_TEXTURE_CLEARTYPE_3x1, DWRITE_RENDERING_MODE_CLEARTYPE_GDI_CLASSIC, "CLEARTYPE_3x1 (gdi)");
    return 0;
}
