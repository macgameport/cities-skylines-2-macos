/* dxgiprobe.c — call the exact DXGI query ANGLE's D3D11 renderer fails on, and print the HRESULT.
 *
 * WHY: on the vanilla-wined3d split, CEF logs
 *   Renderer11.cpp:1108 (rx::Renderer11::populateRenderer11DeviceCaps):
 *       Error querying driver version from DXGI Adapter.
 * ANGLE gets there via IDXGIAdapter::CheckInterfaceSupport(__uuidof(IDXGIDevice), &umdVersion).
 * Prose can't say whether wine's dxgi refuses it or returns garbage — this does.
 *
 * Build: x86_64-w64-mingw32-gcc dxgiprobe.c -o dxgiprobe.exe -ld3d11 -ldxgi -ldxguid -luuid
 * Run under a prefix; flip WINEDLLOVERRIDES=dxgi=n / =b to compare implementations.
 */
#include <windows.h>
#include <stdio.h>
#include <d3d11.h>
#include <dxgi.h>

int main(void)
{
    IDXGIFactory *factory = NULL;
    HRESULT hr = CreateDXGIFactory(&IID_IDXGIFactory, (void **)&factory);
    printf("CreateDXGIFactory            hr=0x%08lX\n", (unsigned long)hr);
    if (FAILED(hr)) return 1;

    IDXGIAdapter *adapter = NULL;
    hr = factory->lpVtbl->EnumAdapters(factory, 0, &adapter);
    printf("EnumAdapters(0)              hr=0x%08lX\n", (unsigned long)hr);
    if (FAILED(hr)) return 1;

    DXGI_ADAPTER_DESC desc;
    hr = adapter->lpVtbl->GetDesc(adapter, &desc);
    if (SUCCEEDED(hr))
        printf("adapter                      \"%ls\"  vendor=0x%04X device=0x%04X\n",
               desc.Description, desc.VendorId, desc.DeviceId);
    else
        printf("GetDesc                      hr=0x%08lX\n", (unsigned long)hr);

    /* THE call. ANGLE Renderer11::populateRenderer11DeviceCaps does exactly this. */
    LARGE_INTEGER umd;
    umd.QuadPart = 0;
    hr = adapter->lpVtbl->CheckInterfaceSupport(adapter, &IID_IDXGIDevice, &umd);
    printf("CheckInterfaceSupport(IDXGIDevice)  hr=0x%08lX  umdVersion=%u.%u.%u.%u\n",
           (unsigned long)hr,
           (unsigned)(umd.HighPart >> 16), (unsigned)(umd.HighPart & 0xFFFF),
           (unsigned)(umd.LowPart  >> 16), (unsigned)(umd.LowPart  & 0xFFFF));
    printf("VERDICT: driver-version query %s\n", SUCCEEDED(hr) ? "SUPPORTED" : "REFUSED (ANGLE logs its error here)");

    /* Second half of what ANGLE needs: does a D3D11 device come up at all? */
    ID3D11Device *dev = NULL;
    D3D_FEATURE_LEVEL fl = 0;
    hr = D3D11CreateDevice(adapter, D3D_DRIVER_TYPE_UNKNOWN, NULL, 0, NULL, 0,
                           D3D11_SDK_VERSION, &dev, &fl, NULL);
    printf("D3D11CreateDevice            hr=0x%08lX  featureLevel=0x%04X\n",
           (unsigned long)hr, (unsigned)fl);
    return 0;
}
