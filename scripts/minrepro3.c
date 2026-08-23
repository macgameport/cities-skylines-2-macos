// minrepro3.c — the STRIPPED reproducer: no fullscreen, no minimize, no focus change.
// v2 revealed the essential defect: after a second swapchain is created on the same HWND,
// presents to the FIRST swapchain complete normally (S_OK, full fps) but stop reaching the
// screen — the screen sticks at the other layer's last content. This tests the minimum:
//   PHASE1  windowed swapchain#1, present MAGENTA 3s      (expect: visible)
//   CREATE2 second swapchain, same HWND, window plainly visible the whole time
//   PHASE2  present CYCLING on sc2 3s                     (expect: visible — new chain works)
//   PHASE2B present RED pulse on sc1 6s                   (bug: screen stuck on stale cycle color)
//   PHASE2C present CYCLING on sc2 again 3s               (does the visible chain still work?)
// Build: x86_64-w64-mingw32-gcc minrepro3.c -o minrepro3.exe -ld3d11 -ldxgi -ldxguid -luuid
#include <windows.h>
#include <d3d11.h>
#include <dxgi.h>
#include <stdio.h>
#include <math.h>
static DWORD g_t0;
static void logmsg(const char *s){printf("[%6lums] %s\n",(unsigned long)(GetTickCount()-g_t0),s);}
static LRESULT CALLBACK WndProc(HWND h,UINT m,WPARAM w,LPARAM l){
    if(m==WM_DESTROY){PostQuitMessage(0);return 0;}
    return DefWindowProc(h,m,w,l);
}
static void loop(ID3D11DeviceContext*ctx,IDXGISwapChain*sc,ID3D11RenderTargetView*rtv,int sec,int color){
    DWORD t0=GetTickCount(),last=t0;unsigned long fr=0,fl=0;MSG msg;
    while((GetTickCount()-t0)/1000<(DWORD)sec){
        while(PeekMessage(&msg,NULL,0,0,PM_REMOVE)){TranslateMessage(&msg);DispatchMessage(&msg);}
        float c[4]={1.0f,0.0f,1.0f,1.0f};
        float p=(float)((GetTickCount()-t0)%1000)/1000.0f,s=0.5f+0.5f*(float)sin(p*6.28318f);
        if(color==1){c[0]=0.0f;c[1]=s;c[2]=1.0f-s;}
        else if(color==2){c[0]=s;c[1]=0.0f;c[2]=0.0f;}
        ctx->lpVtbl->ClearRenderTargetView(ctx,rtv,c);
        HRESULT hr=sc->lpVtbl->Present(sc,1,0);fr++;
        DWORD now=GetTickCount();
        if(now-last>=1000){printf("[%6lums] presenting: %lu fps hr=0x%08lx\n",
            (unsigned long)(now-g_t0),fr-fl,(unsigned long)hr);last=now;fl=fr;}
    }
}
int main(void){
    setvbuf(stdout,NULL,_IONBF,0);g_t0=GetTickCount();
    WNDCLASS wc={0};wc.lpfnWndProc=WndProc;wc.hInstance=GetModuleHandle(NULL);
    wc.lpszClassName="minrepro3";wc.hCursor=LoadCursor(NULL,IDC_ARROW);RegisterClass(&wc);
    HWND hwnd=CreateWindow("minrepro3","minrepro3",WS_OVERLAPPEDWINDOW,100,100,800,600,
        NULL,NULL,wc.hInstance,NULL);
    ShowWindow(hwnd,SW_SHOW);
    DXGI_SWAP_CHAIN_DESC sd={0};
    sd.BufferCount=2;sd.BufferDesc.Width=800;sd.BufferDesc.Height=600;
    sd.BufferDesc.Format=DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferUsage=DXGI_USAGE_RENDER_TARGET_OUTPUT;sd.OutputWindow=hwnd;
    sd.SampleDesc.Count=1;sd.Windowed=TRUE;sd.SwapEffect=DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    ID3D11Device*dev=NULL;ID3D11DeviceContext*ctx=NULL;IDXGISwapChain*sc1=NULL;D3D_FEATURE_LEVEL fl;
    HRESULT hr=D3D11CreateDeviceAndSwapChain(NULL,D3D_DRIVER_TYPE_HARDWARE,NULL,0,NULL,0,
        D3D11_SDK_VERSION,&sd,&sc1,&dev,&fl,&ctx);
    if(FAILED(hr)){printf("FATAL create hr=0x%08lx\n",(unsigned long)hr);return 1;}
    ID3D11Texture2D*bb1=NULL;ID3D11RenderTargetView*rtv1=NULL;
    sc1->lpVtbl->GetBuffer(sc1,0,&IID_ID3D11Texture2D,(void**)&bb1);
    dev->lpVtbl->CreateRenderTargetView(dev,(ID3D11Resource*)bb1,NULL,&rtv1);
    logmsg("PHASE1 MAGENTA on sc1 (3s)");loop(ctx,sc1,rtv1,3,0);
    logmsg("CREATE2 second swapchain, same HWND, window visible, NO minimize, NO fullscreen");
    IDXGIDevice*dxdev=NULL;IDXGIAdapter*ad=NULL;IDXGIFactory*fac=NULL;
    dev->lpVtbl->QueryInterface(dev,&IID_IDXGIDevice,(void**)&dxdev);
    dxdev->lpVtbl->GetAdapter(dxdev,&ad);ad->lpVtbl->GetParent(ad,&IID_IDXGIFactory,(void**)&fac);
    DXGI_SWAP_CHAIN_DESC sd2=sd;IDXGISwapChain*sc2=NULL;
    hr=fac->lpVtbl->CreateSwapChain(fac,(IUnknown*)dev,&sd2,&sc2);
    printf("[%6lums] CreateSwapChain#2 hr=0x%08lx\n",(unsigned long)(GetTickCount()-g_t0),(unsigned long)hr);
    if(FAILED(hr))return 1;
    ID3D11Texture2D*bb2=NULL;ID3D11RenderTargetView*rtv2=NULL;
    sc2->lpVtbl->GetBuffer(sc2,0,&IID_ID3D11Texture2D,(void**)&bb2);
    dev->lpVtbl->CreateRenderTargetView(dev,(ID3D11Resource*)bb2,NULL,&rtv2);
    logmsg("PHASE2 CYCLING on sc2 (3s)");loop(ctx,sc2,rtv2,3,1);
    logmsg("PHASE2B RED pulse on sc1 (6s) — stale color = BUG REPRODUCED");loop(ctx,sc1,rtv1,6,2);
    logmsg("PHASE2C CYCLING on sc2 again (3s)");loop(ctx,sc2,rtv2,3,1);
    logmsg("DONE");return 0;
}
