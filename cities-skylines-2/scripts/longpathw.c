/* longpathw.c — long-path probe using the WIDE APIs, as System.IO.LongFile does.
 * \\?\ only bypasses MAX_PATH on the W functions; the A variants return 206.
 */
#include <windows.h>
#include <stdio.h>
static void rep(const char*l,HANDLE h){
    UINT_PTR v=(UINT_PTR)h;
    printf("  %-36s handle=0x%-8llx GLE=%-5lu %s\n",l,(unsigned long long)v,GetLastError(),
        h==INVALID_HANDLE_VALUE?"INVALID":(v==0?"<<< ZERO HANDLE":"ok"));
}
int main(void){
    wchar_t base[]=L"\\\\?\\C:\\lpwprobe";
    CreateDirectoryW(L"C:\\lpwprobe",NULL);
    wchar_t deep[2048]; wcscpy(deep,base);
    for(int i=0;i<12;i++){
        wchar_t seg[64]; _snwprintf(seg,64,L"\\dirlevel_with_a_fairly_long_name_%d",i);
        wcscat(deep,seg);
        if(!CreateDirectoryW(deep,NULL) && GetLastError()!=ERROR_ALREADY_EXISTS){
            printf("  mkdir failed at depth %d, GLE=%lu\n",i,GetLastError()); }
    }
    wchar_t file[2200]; wcscpy(file,deep); wcscat(file,L"\\content.zip");
    printf("== long-path probe (WIDE apis) ==\n  path length: %d wchars (MAX_PATH=%d)\n\n",(int)wcslen(file),MAX_PATH);

    SetLastError(0);
    HANDLE c=CreateFileW(file,GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL);
    rep("CreateFileW CREATE_ALWAYS",c);
    if(c!=INVALID_HANDLE_VALUE){DWORD w;WriteFile(c,"payload",7,&w,NULL);CloseHandle(c);}

    int zeros=0;
    for(int i=0;i<8;i++){
        SetLastError(0);
        HANDLE h=CreateFileW(file,GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
        char lbl[64]; snprintf(lbl,sizeof lbl,"CreateFileW OPEN_EXISTING #%d",i+1);
        rep(lbl,h);
        if((UINT_PTR)h==0) zeros++;
        if(h!=INVALID_HANDLE_VALUE)CloseHandle(h);
    }
    SetLastError(0); DWORD a=GetFileAttributesW(file);
    printf("  %-36s attrs=0x%-6lx GLE=%-5lu %s\n","GetFileAttributesW (exists)",a,GetLastError(),
        a==INVALID_FILE_ATTRIBUTES?"INVALID":"ok");
    wchar_t miss[2300]; wcscpy(miss,deep); wcscat(miss,L"\\nope.zip");
    SetLastError(0); DWORD am=GetFileAttributesW(miss);
    printf("  %-36s attrs=0x%-6lx GLE=%-5lu %s\n","GetFileAttributesW (MISSING)",am,GetLastError(),
        am==INVALID_FILE_ATTRIBUTES?"correctly INVALID":"<<< FALSE POSITIVE (R-createfile claim)");
    printf("\n== zero handles: %d ==\n",zeros);
    return 0;
}
