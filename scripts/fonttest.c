/* fonttest.c — count the fonts Chromium can actually see.
 *
 * Chromium/CEF enumerates system fonts through DirectWrite (IDWriteFactory ->
 * GetSystemFontCollection). If that returns an empty collection, Chromium renders NO text at all
 * — images and layout are unaffected, which is exactly what a broken Steam client looks like.
 * GDI font APIs can be healthy while DirectWrite is empty, so test DirectWrite specifically.
 *
 * Build: x86_64-w64-mingw32-gcc scripts/fonttest.c -o fonttest.exe -ldwrite -lgdi32 -lole32
 * Run:   wine fonttest.exe
 */
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <dwrite.h>
#include <stdio.h>

static int CALLBACK gdi_cb(const LOGFONTA *lf, const TEXTMETRICA *tm, DWORD type, LPARAM p)
{
    (void)lf; (void)tm; (void)type;
    (*(int *)p)++;
    return 1;
}

int main(void)
{
    /* --- GDI side, for comparison --- */
    HDC dc = GetDC(NULL);
    int gdi_count = 0;
    LOGFONTA lf = {0};
    lf.lfCharSet = DEFAULT_CHARSET;
    EnumFontFamiliesExA(dc, &lf, gdi_cb, (LPARAM)&gdi_count, 0);
    ReleaseDC(NULL, dc);
    printf("GDI EnumFontFamiliesEx : %d families\n", gdi_count);

    /* --- DirectWrite side: what Chromium actually uses --- */
    IDWriteFactory *factory = NULL;
    HRESULT hr = DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, &IID_IDWriteFactory,
                                     (IUnknown **)&factory);
    if (FAILED(hr) || !factory) { printf("DWriteCreateFactory FAILED hr=0x%08lx\n", (unsigned long)hr); return 1; }
    printf("DWriteCreateFactory    : OK\n");

    IDWriteFontCollection *coll = NULL;
    hr = IDWriteFactory_GetSystemFontCollection(factory, &coll, TRUE);
    if (FAILED(hr) || !coll) { printf("GetSystemFontCollection FAILED hr=0x%08lx\n", (unsigned long)hr); return 2; }

    UINT32 n = IDWriteFontCollection_GetFontFamilyCount(coll);
    printf("DWrite font families   : %u   <== Chromium renders no text if this is 0\n", n);

    for (UINT32 i = 0; i < n && i < 8; i++) {
        IDWriteFontFamily *fam = NULL;
        if (FAILED(IDWriteFontCollection_GetFontFamily(coll, i, &fam)) || !fam) continue;
        IDWriteLocalizedStrings *names = NULL;
        if (SUCCEEDED(IDWriteFontFamily_GetFamilyNames(fam, &names)) && names) {
            WCHAR buf[128] = L"";
            IDWriteLocalizedStrings_GetString(names, 0, buf, 128);
            printf("   [%u] %ls\n", i, buf);
            IDWriteLocalizedStrings_Release(names);
        }
        IDWriteFontFamily_Release(fam);
    }
    IDWriteFontCollection_Release(coll);
    IDWriteFactory_Release(factory);
    return 0;
}
