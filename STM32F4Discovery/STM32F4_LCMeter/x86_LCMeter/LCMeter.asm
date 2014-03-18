.386
.model flat, stdcall  ;32 bit memory model
option casemap :none  ;case sensitive

include LCMeter.inc
include Misc.asm

.code

;########################################################################

SetMode proc
	LOCAL	buffer[64]:BYTE

	invoke lstrcpy,addr buffer,offset szLCMeter
	.if mode==CMD_LCMCAP
		mov		eax,offset szCapacitance
	.elseif mode==CMD_LCMIND
		mov		eax,offset szInductance
	.elseif mode==CMD_FRQCH1
		mov		eax,offset szFerquencyCH1
	.elseif mode==CMD_FRQCH2
		mov		eax,offset szFerquencyCH2
	.elseif mode==CMD_FRQCH3
		mov		eax,offset szFerquencyCH3
	.elseif mode==CMD_SCPSET
		mov		eax,offset szScope
	.endif
	invoke lstrcat,addr buffer,eax
	invoke SetWindowText,hWnd,addr buffer
	ret

SetMode endp

FormatFrequency proc uses ebx,frq:DWORD,lpBuffer:DWORD

	mov		eax,frq
	.if eax<1000
		;Hz
		invoke wsprintf,lpBuffer,addr szFmtHz,eax
	.elseif eax<1000000
		;KHz
		invoke wsprintf,lpBuffer,addr szFmtKHz,eax
		mov		ebx,6
		call	InsertDot
	.else
		;MHz
		invoke wsprintf,lpBuffer,addr szFmtMHz,eax
		mov		ebx,9
		call	InsertDot
	.endif
	ret

InsertDot:
	mov		esi,lpBuffer
	invoke lstrlen,esi
	mov		edx,eax
	sub		ebx,edx
	neg		ebx
	mov		al,'.'
	.while ebx<=edx
		xchg	al,[esi+ebx]
		inc		ebx
	.endw
	mov		[esi+ebx],al
	retn

FormatFrequency endp

ButtonProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_LBUTTONDOWN || eax==WM_LBUTTONDBLCLK
		mov		nBtnCount,16
		invoke SetTimer,hWin,1001,500,NULL
	.elseif eax==WM_LBUTTONUP
		invoke KillTimer,hWin,1001
		mov		nBtnCount,16
	.elseif eax==WM_TIMER
		invoke GetWindowLong,hWin,GWL_ID
		mov		ebx,eax
		invoke GetParent,hWin
		mov		esi,eax
		invoke SendMessage,esi,WM_COMMAND,ebx,hWin
		mov		edi,nBtnCount
		shr		edi,4
		.if edi>40
			mov		edi,40
		.endif
		.while edi
			invoke SendMessage,esi,WM_COMMAND,ebx,hWin
			dec		edi
		.endw
		invoke KillTimer,hWin,1001
		invoke SetTimer,hWin,1001,50,NULL
		inc		nBtnCount
		xor		eax,eax
		ret
	.endif
	invoke CallWindowProc,lpOldButtonProc,hWin,uMsg,wParam,lParam
	ret

ButtonProc endp

FrequencyProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	buffer[32]:BYTE
	LOCAL	ps:PAINTSTRUCT
	LOCAL	rect:RECT
	LOCAL	mDC:HDC

	mov		eax,uMsg
	.if eax==WM_PAINT
		invoke GetClientRect,hWin,addr rect
		invoke SendMessage,hWin,WM_GETTEXT,sizeof buffer,addr buffer		
		invoke BeginPaint,hWin,addr ps
		invoke CreateCompatibleDC,ps.hdc
		mov		mDC,eax
		invoke CreateCompatibleBitmap,ps.hdc,rect.right,rect.bottom
		invoke SelectObject,mDC,eax
		push	eax
		invoke CreateSolidBrush,0C0FFFFh
		push	eax
		invoke FillRect,mDC,addr rect,eax
		pop		eax
		invoke DeleteObject,eax
		invoke SelectObject,mDC,hFont
		push	eax
		invoke SetBkMode,mDC,TRANSPARENT
		invoke lstrlen,addr buffer
		mov		edx,eax
		invoke DrawText,mDC,addr buffer,edx,addr rect,DT_CENTER or DT_VCENTER or DT_SINGLELINE
		add		rect.right,15
		pop		eax
		invoke SelectObject,mDC,eax
		invoke BitBlt,ps.hdc,0,0,rect.right,rect.bottom,mDC,0,0,SRCCOPY
		pop		eax
		invoke SelectObject,mDC,eax
		invoke DeleteObject,eax
		invoke DeleteDC,mDC
		invoke EndPaint,hWin,addr ps
		xor		eax,eax
	.elseif eax==WM_SETTEXT
		invoke InvalidateRect,hWin,NULL,TRUE
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
	.else
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
	.endif
	ret

FrequencyProc endp

ScopeProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	ps:PAINTSTRUCT
	LOCAL	rect:RECT
	LOCAL	scprect:RECT
	LOCAL	mDC:HDC
	LOCAL	hBmp:HBITMAP
	LOCAL	pt:POINT
	LOCAL	samplesize:DWORD
	LOCAL	iTmp:DWORD
	LOCAL	fTmp:REAL10
	LOCAL	nMin:DWORD
	LOCAL	nMax:DWORD
	LOCAL	nCenter:DWORD
	LOCAL	pixns:REAL10
	LOCAL	xmul:REAL10
	LOCAL	ymul:REAL10
	LOCAL	adcperiod:REAL10
	LOCAL	buffer[128]:BYTE
	LOCAL	tpos:DWORD
	LOCAL	tptx:DWORD
	LOCAL	tptxc:DWORD
	LOCAL	prevptx:DWORD
	LOCAL	prevpty:DWORD
	LOCAL	xofs:DWORD
	LOCAL	vdofs:DWORD
	LOCAL	ydiv:DWORD

	mov		eax,uMsg
	.if eax==WM_PAINT
		invoke FpToAscii,addr SampleRate,addr buffer,FALSE
		invoke lstrcat,addr buffer,offset szHz
		invoke SetDlgItemText,hScpCld,IDC_STCADCSAMPLERATE,addr buffer
		;Get time in ns for each pixel
		mov		eax,STM32_Cmd.STM32_Scp.ScopeTimeDiv
		mov		ecx,sizeof SCOPETIME
		mul		ecx
		mov		eax,ScopeTime.time[eax]
		mov		iTmp,eax
		fild	iTmp
		mov		iTmp,GRIDSIZE
		fild	iTmp
		fdivp	st(1),st
		fstp	pixns
		;Get x scale
		fld		SampleTime
		fld		pixns
		fdivp	st(1),st
		fstp	xmul
		;Get y scale
		mov		iTmp,ADCMAXMV
		fild	iTmp
		mov		iTmp,GRIDSIZE
		fild	iTmp
		fmulp	st(1),st
		mov		iTmp,ADCDIVMV
		fild	iTmp
		fdivp	st(1),st
		mov		iTmp,ADCMAX
		fild	iTmp
		fdivp	st(1),st
		fstp	ymul
		mov		eax,STM32_Cmd.STM32_Scp.ScopeVoltDiv
		mov		ecx,sizeof SCOPERANGE
		mul		ecx
		mov		vdofs,eax
		mov		eax,ScopeRange.ydiv[eax]
		mov		ydiv,eax

		mov		samplesize,ADCSAMPLESIZE
		;Get nMin and nMax
		mov		esi,offset ADC_Data
		mov		ecx,ADCMAX
		mov		edx,0
		mov		edi,16
		.while edi<samplesize
			movzx	eax,word ptr [esi+edi]
			.if eax<ecx
				mov		ecx,eax
			.elseif eax>edx
				mov		edx,eax
			.endif
			lea		edi,[edi+WORD]
		.endw
		mov		nMin,ecx
		mov		nMax,edx
		mov		nCenter,2048
		invoke GetClientRect,hWin,addr rect
		invoke BeginPaint,hWin,addr ps
		invoke CreateCompatibleDC,ps.hdc
		mov		mDC,eax
		invoke CreateCompatibleBitmap,ps.hdc,rect.right,rect.bottom
		mov		hBmp,eax
		invoke SelectObject,mDC,eax
		push	eax
		invoke GetStockObject,BLACK_BRUSH
		invoke FillRect,mDC,addr rect,eax
		sub		rect.bottom,TEXTHIGHT
		call	DrawScpText

		; Calculate the scope rect
		mov		eax,rect.right
		sub		eax,SCOPEWT
		shr		eax,1
		mov		scprect.left,eax
		add		eax,SCOPEWT
		inc		eax
		mov		scprect.right,eax
		mov		eax,rect.bottom
		sub		eax,SCOPEHT
		shr		eax,1
		mov		scprect.top,eax
		add		eax,SCOPEHT
		inc		eax
		mov		scprect.bottom,eax
		;Create a clip region
		invoke CreateRectRgn,scprect.left,scprect.top,scprect.right,scprect.bottom
		push	eax
		invoke SelectClipRgn,mDC,eax
		pop		eax
		invoke DeleteObject,eax

		mov		tpos,0
		mov		xofs,0
		.if STM32_Cmd.STM32_Scp.ScopeTrigger
			;Get trigger y position
			mov		eax,STM32_Cmd.STM32_Scp.ScopeTriggerLevel
			sub		eax,nCenter
			neg		eax
			mov		iTmp,eax
			fild	iTmp
			fld		ymul
			fmulp	st(1),st
			fistp	iTmp
			mov		eax,iTmp
			add		eax,SCOPEHT/2
			add		eax,scprect.top
			mov		tpos,eax
			mov		tptx,0
			mov		tptxc,0

			;Find trigger xofs
			call	DrawCurve
			.if tptx
				mov		esi,tptx
				mov		edi,tpos
				.while esi<scprect.right
					invoke GetPixel,mDC,esi,edi
					.break .if eax
					inc		esi
				.endw
				.if esi<scprect.right
					sub		esi,scprect.left
					mov		xofs,esi
				.endif
			.endif
			invoke GetStockObject,BLACK_BRUSH
			invoke FillRect,mDC,addr scprect,eax
		.endif
		;Draw grid
		call	DrawGrid
		;Draw trigger line
		call	DrawTrigger
		;Draw curve
		call	DrawCurve
		add		rect.bottom,TEXTHIGHT
		invoke BitBlt,ps.hdc,0,0,rect.right,rect.bottom,mDC,0,0,SRCCOPY
		pop		eax
		invoke SelectObject,mDC,eax
		invoke DeleteObject,eax
		invoke DeleteDC,mDC
		invoke EndPaint,hWin,addr ps
		xor		eax,eax
	.else
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
	.endif
	ret
	
DrawScpText:
	invoke SetBkMode,mDC,TRANSPARENT
	invoke SetTextColor,mDC,0FFFFFFh
	mov		eax,vdofs
	lea		esi,ScopeRange.range[eax]
	mov		pt.x,10
	mov		eax,rect.bottom
	mov		pt.y,eax
	call	TextDraw
	mov		pt.x,200
	mov		eax,nMax
	sub		eax,nMin
	mov		ecx,12500
	imul	ecx
	mov		ecx,3050
	idiv	ecx
	mov		iTmp,eax
	fld		ymul
	fild	iTmp
	fmulp	st(1),st
	fistp	iTmp
	invoke wsprintf,addr buffer[64],offset szFmtPPV,iTmp
	;Insert a'.' after the first digit
	mov		eax,dword ptr buffer[64+1]
	mov		buffer[64+1],'.'
	mov		dword ptr buffer[64+2],eax
	mov		dword ptr buffer[64+6],0
	invoke lstrcpy,addr buffer,offset szFmtVPP
	invoke lstrcat,addr buffer,addr buffer[64]
	lea		esi,buffer
	call	TextDraw
	mov		pt.x,10
	add		pt.y,20
	mov		eax,STM32_Cmd.STM32_Scp.ScopeTimeDiv
	mov		ecx,sizeof SCOPETIME
	mul		ecx
	lea		esi,ScopeTime.range[eax]
	call	TextDraw
	mov		eax,STM32_Cmd.STM32_Frq.FrequencySCP
	.if eax
		mov		pt.x,200
		mov		iTmp,eax
		.if eax>1000000
			;Get signals period in ns
			fld		ten_9
			mov		ebx,offset sznS
		.elseif eax>1000
			;Get signals period in us
			fld		ten_6
			mov		ebx,offset szuS
		.else
			;Get signals period in ms
			fld		ten_3
			mov		ebx,offset szmS
		.endif
		fild	iTmp
		fdivp	st(1),st
		fstp	fTmp
		invoke FpToAscii,addr fTmp,addr buffer[64],FALSE
		mov		eax,64
		.while buffer[eax]
			.if buffer[eax]=='.'
				mov		buffer[eax+4],0
				.break
			.endif
			inc		eax
		.endw
		invoke lstrcpy,addr buffer,offset szFmtPER
		invoke lstrcat,addr buffer,addr buffer[64]
		invoke lstrcat,addr buffer,ebx
		lea		esi,buffer
		call	TextDraw
	.endif
	retn

TextDraw:
	invoke lstrlen,esi
	invoke TextOut,mDC,pt.x,pt.y,esi,eax
	retn

DrawTrigger:
	.if tpos
		; Create trigger pen
		invoke CreatePen,PS_SOLID,1,0000C0h
		invoke SelectObject,mDC,eax
		push	eax
		invoke MoveToEx,mDC,scprect.left,tpos,NULL
		invoke LineTo,mDC,scprect.right,tpos
		pop		eax
		invoke SelectObject,mDC,eax
		invoke DeleteObject,eax
	.endif
	retn

DrawGrid:
	; Create gridlines pen
	invoke CreatePen,PS_SOLID,1,404040h
	invoke SelectObject,mDC,eax
	push	eax
	;Draw horizontal lines
	mov		edi,scprect.top
	xor		ecx,ecx
	.while ecx<GRIDY+1
		push	ecx
		invoke MoveToEx,mDC,scprect.left,edi,NULL
		invoke LineTo,mDC,scprect.right,edi
		add		edi,GRIDSIZE
		pop		ecx
		inc		ecx
	.endw
	;Draw vertical lines
	mov		edi,scprect.left
	xor		ecx,ecx
	.while ecx<GRIDX+1
		push	ecx
		invoke MoveToEx,mDC,edi,scprect.top,NULL
		invoke LineTo,mDC,edi,scprect.bottom
		add		edi,GRIDSIZE
		pop		ecx
		inc		ecx
	.endw
	pop		eax
	invoke SelectObject,mDC,eax
	invoke DeleteObject,eax
	retn

DrawCurve:
	invoke CreatePen,PS_SOLID,2,008000h
	invoke SelectObject,mDC,eax
	push	eax
	.if fSubSampling && !fNoFrequency
		fld		ten_9
		fild	STM32_Cmd.STM32_Frq.FrequencySCP
		fdivp	st(1),st
		fstp	adcperiod
		xor		ebx,ebx
		call	GetPointSubSample
		invoke MoveToEx,mDC,pt.x,pt.y,NULL
		mov		eax,pt.x
		mov		prevptx,eax
		mov		eax,pt.y
		mov		prevpty,eax
		lea		ebx,[ebx+1]
		.while TRUE
			call	GetPointSubSample
			.if pt.y
				invoke LineTo,mDC,pt.x,pt.y
				call	IsTrigger
			.endif
			mov		eax,pt.x
			.break .if sdword ptr eax>scprect.right
			lea		ebx,[ebx+1]
		.endw
	.else
		mov		edi,16
		mov		esi,offset ADC_Data
		xor		ebx,ebx
		call	GetPoint
		invoke MoveToEx,mDC,pt.x,pt.y,NULL
		mov		eax,pt.x
		mov		prevptx,eax
		mov		eax,pt.y
		mov		prevpty,eax
		lea		edi,[edi+WORD]
		lea		ebx,[ebx+1]
		.while edi<samplesize
			call	GetPoint
			invoke LineTo,mDC,pt.x,pt.y
			call	IsTrigger
			mov		eax,pt.x
			.break .if sdword ptr eax>scprect.right
			lea		edi,[edi+WORD]
			lea		ebx,[ebx+1]
		.endw
	.endif
	pop		eax
	invoke SelectObject,mDC,eax
	invoke DeleteObject,eax
	retn

IsTrigger:
	.if !tptx || tptxc<=1
		mov		ecx,pt.y
		mov		edx,prevpty
		.if STM32_Cmd.STM32_Scp.ScopeTrigger==1
			;Rising
			.if !tptxc
				.if edx>=tpos && ecx<tpos
					mov		ecx,prevptx
					mov		tptx,ecx
					mov		tptxc,1
				.endif
			.else
				.if edx<tpos && ecx<tpos
					mov		tptxc,2
				.else
					mov		tptx,0
					mov		tptxc,0
				.endif
			.endif
		.elseif STM32_Cmd.STM32_Scp.ScopeTrigger==2
			;Falling
			.if !tptxc
				.if edx<=tpos && ecx>tpos
					mov		ecx,prevptx
					mov		tptx,ecx
					mov		tptxc,1
				.endif
			.else
				.if edx>tpos && ecx>tpos
					mov		tptxc,2
				.else
					mov		tptx,0
					mov		tptxc,0
				.endif
			.endif
		.endif
		mov		ecx,pt.x
		mov		prevptx,ecx
		mov		ecx,pt.y
		mov		prevpty,ecx
	.endif
	retn

GetPoint:
	;Get X position
	fld		xmul
	mov		iTmp,ebx
	fild	iTmp
	fmulp	st(1),st
	fistp	iTmp
	mov		eax,iTmp
	add		eax,scprect.left
	sub		eax,xofs
	mov		pt.x,eax
	;Get y position
	fld		ymul
	movzx	eax,word ptr [esi+edi]
	sub		eax,nCenter
	neg		eax

	mov		ecx,4096
	imul	ecx
	mov		ecx,ydiv
	idiv	ecx

	mov		iTmp,eax
	fild	iTmp
	fmulp	st(1),st
	fistp	iTmp
	mov		eax,iTmp
	add		eax,SCOPEHT/2
	add		eax,scprect.top
	mov		pt.y,eax
	retn

GetPointSubSample:
	;Get X position
	mov		eax,STM32_Cmd.STM32_Scp.ScopeTimeDiv
	mov		ecx,sizeof SCOPETIME
	mul		ecx
	mov		eax,ScopeTime.time[eax]
	mov		iTmp,eax
	fild	iTmp
	fld		adcperiod
	fdivp	st(1),st
	mov		iTmp,2048/64
	fild	iTmp
	fmulp	st(1),st
	mov		iTmp,ebx
	fild	iTmp
	fdivrp	st(1),st
	fistp	iTmp
	mov		eax,iTmp
	add		eax,scprect.left
	sub		eax,xofs
	mov		pt.x,eax
	;Get y position
	mov		eax,ebx
	and		eax,2047
	mov		eax,SubSample[eax*DWORD]
	.if eax
		sub		eax,nCenter
		neg		eax

		mov		ecx,4096
		imul	ecx
		mov		ecx,ydiv
		idiv	ecx

		mov		iTmp,eax
		fld		ymul
		fild	iTmp
		fmulp	st(1),st
		fistp	iTmp
		mov		eax,iTmp
		add		eax,SCOPEHT/2
		add		eax,scprect.top
	.endif
	mov		pt.y,eax
	retn

ScopeProc endp

SampleThreadProc proc lParam:DWORD
	LOCAL	buffer[32]:BYTE

	mov		fThreadDone,FALSE
	.if connected && !fExitThread
		;Read 16 bytes from STM32F4xx ram and store it in STM32_Cmd.
		invoke STLinkRead,lParam,20000020h,offset STM32_Cmd.STM32_Frq,4*DWORD
		.if !eax
			jmp		Err
		.endif
		mov		edx,STM32_Cmd.STM32_Frq.FrequencySCP
		invoke FormatFrequency,edx,addr buffer
		invoke SetWindowText,hScp,addr buffer
		
		invoke RtlZeroMemory,offset ADC_Data,sizeof ADC_Data
		;Copy current scope settings
		invoke RtlMoveMemory,offset STM32_Scp,offset STM32_Cmd.STM32_Scp,sizeof STM32_SCP
		invoke GetSampleTime,offset STM32_Scp
		invoke GetSignalPeriod
		invoke GetSamplesPrPeriod
		invoke GetTotalSamples,offset STM32_Scp
		mov		STM32_Scp.ADC_SampleSize,eax
		invoke STLinkWrite,lParam,20000030h,offset STM32_Scp,sizeof STM32_SCP
		.if !eax
			jmp		Err
		.endif
		invoke STLinkWrite,lParam,20000014h,addr mode,DWORD
		.if !eax
			jmp		Err
		.endif
		xor		ebx,ebx
		.while ebx<50 && !fExitThread
			invoke Sleep,100
			invoke STLinkRead,lParam,20000014h,offset STM32_Cmd,DWORD
			.if !eax
				jmp		Err
			.endif
			.break .if !STM32_Cmd.Cmd
			inc		ebx
		.endw
		.if !fExitThread
			mov		fNoFrequency,TRUE
			invoke STLinkRead,lParam,20008000h,offset ADC_Data,STM32_Scp.ADC_SampleSize
			.if !eax
				jmp		Err
			.endif
			.if fSubSampling
				invoke ScopeSubSampling
			.endif
			invoke InvalidateRect,hScpScrn,NULL,TRUE
			invoke UpdateWindow,hScpScrn
			mov		fSampleDone,TRUE
		.endif
	.endif
	mov		fThreadDone,TRUE
	ret
Err:
	mov		connected,FALSE
	mov		fThreadDone,TRUE
	ret

SampleThreadProc endp

HscChildProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	resfrq:DWORD

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		invoke GetDlgItem,hWin,IDC_UDCHSC
		mov		hHsc,eax
		mov		eax,STM32_Cmd.STM32_Hsc.HSCDiv
		inc		eax
		invoke ClockToFrequency,eax,STM32_CLOCK/4
		invoke SetDlgItemInt,hWin,IDC_EDTHSCFRQ,eax,FALSE
		invoke ImageList_GetIcon,hIml,0,ILD_NORMAL
		mov		ebx,eax
		invoke SendDlgItemMessage,hWin,IDC_BTNHSCDN,BM_SETIMAGE,IMAGE_ICON,ebx
		invoke ImageList_GetIcon,hIml,1,ILD_NORMAL
		mov		ebx,eax
		invoke SendDlgItemMessage,hWin,IDC_BTNHSCUP,BM_SETIMAGE,IMAGE_ICON,ebx
		push	0
		push	IDC_BTNHSCDN
		mov		eax,IDC_BTNHSCUP
		.while eax
			invoke GetDlgItem,hWin,eax
			invoke SetWindowLong,eax,GWL_WNDPROC,offset ButtonProc
			mov		lpOldButtonProc,eax
			pop		eax
		.endw
	.elseif	eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax==IDC_BTNHSCDN
				invoke GetDlgItemInt,hWin,IDC_EDTHSCFRQ,NULL,FALSE
				.if eax>1
					dec		eax
					mov		resfrq,eax
					inc		eax
					.while eax!=resfrq
						dec		eax
						push	eax
						mov		edx,eax
						invoke GetHSCFrq,edx,addr resfrq
						pop		eax
					.endw
					
					invoke SetHSC,hWin,eax
				.endif
			.elseif eax==IDC_BTNHSCUP
				invoke GetDlgItemInt,hWin,IDC_EDTHSCFRQ,NULL,FALSE
				.if eax<50000000
					inc		eax
					invoke SetHSC,hWin,eax
				.endif
			.endif
		.elseif edx==EN_KILLFOCUS
			.if eax==IDC_EDTHSCFRQ
				invoke GetDlgItemInt,hWin,IDC_EDTHSCFRQ,NULL,FALSE
				invoke SetHSC,hWin,eax
			.endif
		.endif
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

HscChildProc endp

LcmChildProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		invoke GetDlgItem,hWin,IDC_UDCLCM
		mov		hLcm,eax
	.elseif	eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax==IDC_BTNLCMMODE
				.if mode==CMD_LCMCAP
					mov		mode,CMD_LCMIND
				.elseif mode==CMD_LCMIND
					mov		mode,CMD_LCMCAP
				.endif
				.if connected
					invoke STLinkWrite,hWnd,20000014h,addr mode,DWORD
					invoke SetMode
				.endif
			.elseif eax==IDC_BTNLCMCAL
				mov		mode,CMD_LCMCAL
				.if connected
					invoke STLinkWrite,hWnd,20000014h,addr mode,DWORD
					mov		mode,CMD_LCMCAP
					invoke SetMode
				.endif
			.endif
		.endif
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

LcmChildProc endp

ScopeScrnChildProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		invoke GetDlgItem,hWin,IDC_UDCSCPSCRN
		mov		hScpScrn,eax
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

ScopeScrnChildProc endp

ScpChildProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	
	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		invoke GetDlgItem,hWin,IDC_UDCSCP
		mov		hScp,eax
		invoke SendDlgItemMessage,hWin,IDC_CHKTRIPLE,BM_SETCHECK,BST_CHECKED,0
		invoke SendDlgItemMessage,hWin,IDC_TRBADCCLOCK,TBM_SETRANGE,FALSE,3 SHL 16
		mov		eax,3
		sub		eax,STM32_Cmd.STM32_Scp.ADC_Prescaler
		invoke SendDlgItemMessage,hWin,IDC_TRBADCCLOCK,TBM_SETPOS,TRUE,eax
		invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_SETRANGE,FALSE,(20-5) SHL 16
		mov		eax,20-5
		sub		eax,STM32_Cmd.STM32_Scp.ADC_TwoSamplingDelay
		invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_SETPOS,TRUE,eax
		invoke SendDlgItemMessage,hWin,IDC_TRBTIMEDIV,TBM_SETRANGE,FALSE,MAXTIMEDIV SHL 16
		mov		eax,STM32_Cmd.STM32_Scp.ScopeTimeDiv
		invoke SendDlgItemMessage,hWin,IDC_TRBTIMEDIV,TBM_SETPOS,TRUE,eax
		invoke SendDlgItemMessage,hWin,IDC_TRBVOLTDIV,TBM_SETRANGE,FALSE,MAXVOLTDIV SHL 16
		mov		eax,STM32_Cmd.STM32_Scp.ScopeVoltDiv
		invoke SendDlgItemMessage,hWin,IDC_TRBVOLTDIV,TBM_SETPOS,TRUE,eax
		mov		eax,STM32_Cmd.STM32_Scp.ScopeTrigger
		add		eax,IDC_RBNTRIGGERNONE
		invoke SendDlgItemMessage,hWin,eax,BM_SETCHECK,BST_CHECKED,0
		invoke SendDlgItemMessage,hWin,IDC_TRBTRIGGERLEVEL,TBM_SETRANGE,FALSE,255 SHL 16
		mov		eax,STM32_Cmd.STM32_Scp.ScopeTriggerLevel
		shr		eax,4
		invoke SendDlgItemMessage,hWin,IDC_TRBTRIGGERLEVEL,TBM_SETPOS,TRUE,eax
		invoke SendDlgItemMessage,hWin,IDC_TRBVPOS,TBM_SETRANGE,FALSE,4095 SHL 16
		mov		eax,STM32_Cmd.STM32_Scp.ScopeVPos
		invoke SendDlgItemMessage,hWin,IDC_TRBVPOS,TBM_SETPOS,TRUE,eax
		invoke ImageList_GetIcon,hIml,0,ILD_NORMAL
		mov		ebx,eax
		push	0
		push	IDC_BTNSRD
		push	IDC_BTNADD
		push	IDC_BTNTDD
		push	IDC_BTNVDD
		push	IDC_BTNVPD
		mov		eax,IDC_BTNTLD
		.while eax
			invoke GetDlgItem,hWin,eax
			mov		edi,eax
			invoke SendMessage,edi,BM_SETIMAGE,IMAGE_ICON,ebx
			invoke SetWindowLong,edi,GWL_WNDPROC,offset ButtonProc
			mov		lpOldButtonProc,eax
			pop		eax
		.endw
		invoke ImageList_GetIcon,hIml,1,ILD_NORMAL
		mov		ebx,eax
		push	0
		push	IDC_BTNSRU
		push	IDC_BTNADU
		push	IDC_BTNTDU
		push	IDC_BTNVDU
		push	IDC_BTNVPU
		mov		eax,IDC_BTNTLU
		.while eax
			invoke GetDlgItem,hWin,eax
			mov		edi,eax
			invoke SendMessage,edi,BM_SETIMAGE,IMAGE_ICON,ebx
			invoke SetWindowLong,edi,GWL_WNDPROC,offset ButtonProc
			mov		lpOldButtonProc,eax
			pop		eax
		.endw
		invoke GetSampleTime,offset STM32_Cmd.STM32_Scp
	.elseif	eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax>=IDC_RBNTRIGGERNONE && eax<=IDC_RBNTRIGGERFALLING
				sub		eax,IDC_RBNTRIGGERNONE
				mov		STM32_Cmd.STM32_Scp.ScopeTrigger,eax
				invoke InvalidateRect,hScpScrn,NULL,TRUE
			.elseif eax==IDC_CHKSUBSAMPLING
				xor		fSubSampling,TRUE
			.elseif eax==IDC_CHKHOLDSAMPLING
				xor		fHoldSampling,TRUE
			.elseif eax==IDC_BTNSRD
				mov		eax,STM32_Cmd.STM32_Scp.ADC_Prescaler
				.if eax<3
					inc		eax
					mov		STM32_Cmd.STM32_Scp.ADC_Prescaler,eax
					sub		eax,3
					neg		eax
					invoke SendDlgItemMessage,hWin,IDC_TRBADCCLOCK,TBM_SETPOS,TRUE,eax
				.endif
			.elseif eax==IDC_BTNSRU
				mov		eax,STM32_Cmd.STM32_Scp.ADC_Prescaler
				.if eax
					dec		eax
					mov		STM32_Cmd.STM32_Scp.ADC_Prescaler,eax
					sub		eax,3
					neg		eax
					invoke SendDlgItemMessage,hWin,IDC_TRBADCCLOCK,TBM_SETPOS,TRUE,eax
				.endif
			.elseif eax==IDC_BTNADD
				.if STM32_Cmd.STM32_Scp.ADC_TripleMode
					mov		eax,STM32_Cmd.STM32_Scp.ADC_TwoSamplingDelay
					.if eax<15
						inc		eax
						mov		STM32_Cmd.STM32_Scp.ADC_TwoSamplingDelay,eax
						sub		eax,15
						neg		eax
						invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_SETPOS,TRUE,eax
					.endif
				.else
					mov		eax,STM32_Cmd.STM32_Scp.ADC_SampleTime
					.if eax<7
						inc		eax
						mov		STM32_Cmd.STM32_Scp.ADC_SampleTime,eax
						sub		eax,7
						neg		eax
						invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_SETPOS,TRUE,eax
					.endif
				.endif
			.elseif eax==IDC_BTNADU
				.if STM32_Cmd.STM32_Scp.ADC_TripleMode
					mov		eax,STM32_Cmd.STM32_Scp.ADC_TwoSamplingDelay
					.if eax
						dec		eax
						mov		STM32_Cmd.STM32_Scp.ADC_TwoSamplingDelay,eax
						sub		eax,15
						neg		eax
						invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_SETPOS,TRUE,eax
					.endif
				.else
					mov		eax,STM32_Cmd.STM32_Scp.ADC_SampleTime
					.if eax
						dec		eax
						mov		STM32_Cmd.STM32_Scp.ADC_SampleTime,eax
						sub		eax,7
						neg		eax
						invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_SETPOS,TRUE,eax
					.endif
				.endif
			.elseif eax==IDC_BTNTDU
				mov		eax,STM32_Cmd.STM32_Scp.ScopeTimeDiv
				.if eax<MAXTIMEDIV
					inc		eax
					mov		STM32_Cmd.STM32_Scp.ScopeTimeDiv,eax
					invoke SendDlgItemMessage,hWin,IDC_TRBTIMEDIV,TBM_SETPOS,TRUE,eax
				.endif
			.elseif eax==IDC_BTNTDD
				mov		eax,STM32_Cmd.STM32_Scp.ScopeTimeDiv
				.if eax
					dec		eax
					mov		STM32_Cmd.STM32_Scp.ScopeTimeDiv,eax
					invoke SendDlgItemMessage,hWin,IDC_TRBTIMEDIV,TBM_SETPOS,TRUE,eax
				.endif
			.elseif eax==IDC_BTNVDU
				mov		eax,STM32_Cmd.STM32_Scp.ScopeVoltDiv
				.if eax<MAXVOLTDIV
					inc		eax
					mov		STM32_Cmd.STM32_Scp.ScopeVoltDiv,eax
					invoke SendDlgItemMessage,hWin,IDC_TRBVOLTDIV,TBM_SETPOS,TRUE,eax
				.endif
			.elseif eax==IDC_BTNVDD
				mov		eax,STM32_Cmd.STM32_Scp.ScopeVoltDiv
				.if eax
					dec		eax
					mov		STM32_Cmd.STM32_Scp.ScopeVoltDiv,eax
					invoke SendDlgItemMessage,hWin,IDC_TRBVOLTDIV,TBM_SETPOS,TRUE,eax
				.endif
			.elseif eax==IDC_BTNVPU
				mov		eax,STM32_Cmd.STM32_Scp.ScopeVPos
				.if eax<4095
					inc		eax
					mov		STM32_Cmd.STM32_Scp.ScopeVPos,eax
					invoke SendDlgItemMessage,hWin,IDC_TRBVPOS,TBM_SETPOS,TRUE,eax
				.endif
			.elseif eax==IDC_BTNVPD
				mov		eax,STM32_Cmd.STM32_Scp.ScopeVPos
				.if eax
					dec		eax
					mov		STM32_Cmd.STM32_Scp.ScopeVPos,eax
					invoke SendDlgItemMessage,hWin,IDC_TRBVPOS,TBM_SETPOS,TRUE,eax
				.endif
			.elseif eax==IDC_BTNTLU
				mov		eax,STM32_Cmd.STM32_Scp.ScopeTriggerLevel
				shr		eax,4
				.if eax<255
					inc		eax
					push	eax
					invoke SendDlgItemMessage,hWin,IDC_TRBTRIGGERLEVEL,TBM_SETPOS,TRUE,eax
					pop		eax
					shl		eax,4
					mov		STM32_Cmd.STM32_Scp.ScopeTriggerLevel,eax
				.endif
			.elseif eax==IDC_BTNTLD
				mov		eax,STM32_Cmd.STM32_Scp.ScopeTriggerLevel
				shr		eax,4
				.if eax
					dec		eax
					push	eax
					invoke SendDlgItemMessage,hWin,IDC_TRBTRIGGERLEVEL,TBM_SETPOS,TRUE,eax
					pop		eax
					shl		eax,4
					mov		STM32_Cmd.STM32_Scp.ScopeTriggerLevel,eax
				.endif
			.elseif eax==IDC_CHKTRIPLE
				xor		STM32_Cmd.STM32_Scp.ADC_TripleMode,TRUE
				.if STM32_Cmd.STM32_Scp.ADC_TripleMode
					invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_SETRANGE,FALSE,(20-5) SHL 16
					mov		eax,20-5
					sub		eax,STM32_Cmd.STM32_Scp.ADC_TwoSamplingDelay
					invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_SETPOS,TRUE,eax
				.else
					invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_SETRANGE,FALSE,7 SHL 16
					mov		eax,7
					sub		eax,STM32_Cmd.STM32_Scp.ADC_SampleTime
					invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_SETPOS,TRUE,eax
				.endif
			.elseif eax==IDC_BTNAUTO
				invoke GetAuto,hWin
			.endif
		.endif
	.elseif eax==WM_HSCROLL
		invoke GetDlgCtrlID,lParam
		.if eax==IDC_TRBADCCLOCK
			;ADC Clock Divider
			invoke SendDlgItemMessage,hWin,IDC_TRBADCCLOCK,TBM_GETPOS,0,0
			sub		eax,3
			neg		eax
			mov		STM32_Cmd.STM32_Scp.ADC_Prescaler,eax
		.elseif eax==IDC_TRBADCDELAY
			.if STM32_Cmd.STM32_Scp.ADC_TripleMode
				;ADC Two Sampling Delay
				invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_GETPOS,0,0
				sub		eax,20-5
				neg		eax
				mov		STM32_Cmd.STM32_Scp.ADC_TwoSamplingDelay,eax
			.else
				;ADC Sample time
				invoke SendDlgItemMessage,hWin,IDC_TRBADCDELAY,TBM_GETPOS,0,0
				sub		eax,7
				neg		eax
				mov		STM32_Cmd.STM32_Scp.ADC_SampleTime,eax
			.endif
		.elseif eax==IDC_TRBTIMEDIV
			;Scope Time / Div
			invoke SendDlgItemMessage,hWin,IDC_TRBTIMEDIV,TBM_GETPOS,0,0
			mov		STM32_Cmd.STM32_Scp.ScopeTimeDiv,eax
		.elseif eax==IDC_TRBVOLTDIV
			;Scope Volt / Div
			invoke SendDlgItemMessage,hWin,IDC_TRBVOLTDIV,TBM_GETPOS,0,0
			mov		STM32_Cmd.STM32_Scp.ScopeVoltDiv,eax
		.elseif eax==IDC_TRBTRIGGERLEVEL
			;Scope Trigger Level
			invoke SendDlgItemMessage,hWin,IDC_TRBTRIGGERLEVEL,TBM_GETPOS,0,0
			shl		eax,4
			mov		STM32_Cmd.STM32_Scp.ScopeTriggerLevel,eax
		.elseif eax==IDC_TRBVPOS
			;Scope V-Pos
			invoke SendDlgItemMessage,hWin,IDC_TRBVPOS,TBM_GETPOS,0,0
			mov		STM32_Cmd.STM32_Scp.ScopeVPos,eax
		.endif
		invoke InvalidateRect,hScpScrn,NULL,TRUE
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

ScpChildProc endp

DlgProc	proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	buffer[32]:BYTE
	LOCAL	tid:DWORD

	mov		eax,uMsg
	.if	eax==WM_INITDIALOG
		mov		eax,hWin
		mov		hWnd,eax
		mov		STM32_Cmd.STM32_Hsc.HSCDiv,50000-1
		mov		STM32_Cmd.STM32_Hsc.HSCSet,1
		mov		STM32_Cmd.STM32_Scp.ADC_Prescaler,0
		mov		STM32_Cmd.STM32_Scp.ADC_TwoSamplingDelay,0
		mov		STM32_Cmd.STM32_Scp.ScopeTrigger,1
		mov		STM32_Cmd.STM32_Scp.ScopeTriggerLevel,2048
		mov		STM32_Cmd.STM32_Scp.ScopeTimeDiv,8
		mov		STM32_Cmd.STM32_Scp.ScopeVoltDiv,8
		mov		STM32_Cmd.STM32_Scp.ScopeVPos,2245
		mov		STM32_Cmd.STM32_Scp.ADC_TripleMode,TRUE
		invoke CreateFontIndirect,addr Tahoma_36
		mov		hFont,eax
		invoke ImageList_Create,16,16,ILC_COLOR24 or ILC_MASK,2,0
		mov		hIml,eax
		invoke LoadBitmap,hInstance,100
		mov		ebx,eax
		invoke ImageList_AddMasked,hIml,ebx,0FF00FFh
		invoke DeleteObject,ebx
		;Create FRQ child dialog
		invoke CreateDialogParam,hInstance,IDD_DLGHSC,hWin,addr HscChildProc,0
		mov		hHscCld,eax
		;Create LCM child dialog
		invoke CreateDialogParam,hInstance,IDD_DLGLCMETER,hWin,addr LcmChildProc,0
		mov		hLcmCld,eax
		;Create scope screen child dialog
		invoke CreateDialogParam,hInstance,IDD_DLGSCPSCRNCLD,hWin,addr ScopeScrnChildProc,0
		mov		hScpScrnCld,eax
		;Create scope child dialog
		invoke CreateDialogParam,hInstance,IDD_DLGSCP,hWin,addr ScpChildProc,0
		mov		hScpCld,eax
		mov		STM32_Cmd.STM32_Scp.ScopeTrigger,1
		mov		mode,CMD_LCMCAP
		xor		ebx,ebx
		.while ebx<ADCSAMPLESIZE/2
			mov		ADC_Data[ebx*WORD],2048
			inc		ebx
		.endw
	.elseif	eax==WM_COMMAND
		mov edx,wParam
		movzx eax,dx
		shr edx,16
		.if edx==BN_CLICKED
			.if eax==IDOK
				.if !connected
					;Connect to the STLink
					invoke STLinkConnect,hWin
					.if eax && eax!=IDIGNORE && eax!=IDABORT
						mov		connected,eax
						mov		mode,CMD_LCMCAP
						invoke SetMode
						invoke STLinkWrite,hWin,20000014h,addr mode,DWORD
						;Create a timer. The event will read the frequency, format it and display the result
						invoke SetTimer,hWin,1000,100,NULL
					.endif
				.endif
			.elseif eax==IDCANCEL
				invoke	SendMessage,hWin,WM_CLOSE,NULL,NULL
			.elseif eax==IDC_BTNMODE
				.if mode==CMD_LCMCAP || mode==CMD_LCMIND
					;High Speed Clock
					invoke ShowWindow,hScpCld,SW_HIDE
					invoke ShowWindow,hLcmCld,SW_HIDE
					invoke ShowWindow,hHscCld,SW_SHOW
					mov		mode,CMD_FRQCH1
					.if connected
						invoke STLinkWrite,hWin,20000014h,addr mode,DWORD
						.if !eax
							invoke KillTimer,hWin,1000
							jmp		Err
						.endif
					.endif
				.elseif mode==CMD_FRQCH1
					;Scope
					invoke ShowWindow,hLcmCld,SW_HIDE
					invoke ShowWindow,hHscCld,SW_HIDE
					invoke ShowWindow,hScpCld,SW_SHOW
					mov		fSampleDone,TRUE
					mov		mode,CMD_SCPSET
				.elseif mode==CMD_SCPSET
					;LCMeter
					invoke ShowWindow,hScpCld,SW_HIDE
					invoke ShowWindow,hHscCld,SW_HIDE
					invoke ShowWindow,hLcmCld,SW_SHOW
					mov		mode,CMD_LCMCAP
					.if connected
						invoke STLinkWrite,hWin,20000014h,addr mode,DWORD
						.if !eax
							invoke KillTimer,hWin,1000
							jmp		Err
						.endif
					.endif
				.endif
				invoke SetMode
			.endif
		.endif
	.elseif	eax==WM_TIMER
		invoke KillTimer,hWin,1000
		.if eax
			.if mode==CMD_SCPSET
				.if !fHoldSampling && fSampleDone
					mov		fSampleDone,FALSE
					invoke CreateThread,NULL,NULL,addr SampleThreadProc,hWin,0,addr tid
					invoke CloseHandle,eax
				.endif
			.elseif mode==CMD_FRQCH1
				;Read 16 bytes from STM32F4xx ram and store it in STM32_Cmd.
				invoke STLinkRead,hWin,20000020h,offset STM32_Cmd.STM32_Frq,4*DWORD
				mov		edx,STM32_Cmd.STM32_Frq.Frequency
				invoke FormatFrequency,edx,addr buffer
				invoke SetWindowText,hHsc,addr buffer
			.elseif mode==CMD_LCMCAP
				;Read 16 bytes from STM32F4xx ram and store it in STM32_Cmd.
				invoke STLinkRead,hWin,20000020h,offset STM32_Cmd.STM32_Frq,4*DWORD
				invoke CalculateCapacitor,addr buffer
				invoke SetWindowText,hLcm,addr buffer
			.elseif mode==CMD_LCMIND
				;Read 16 bytes from STM32F4xx ram and store it in STM32_Cmd.
				invoke STLinkRead,hWin,20000020h,offset STM32_Cmd.STM32_Frq,4*DWORD
				invoke CalculateInductor,addr buffer
				invoke SetWindowText,hLcm,addr buffer
			.endif
			invoke SetTimer,hWin,1000,100,NULL
		.else
Err:
			mov		connected,FALSE
		.endif
	.elseif	eax==WM_CLOSE
		mov		fExitThread,TRUE
		invoke KillTimer,hWin,1000
		xor		ebx,ebx
		.if mode==CMD_SCPSET
			.while !fThreadDone && ebx<5
				invoke GetMessage,addr msg,NULL,0,0
			  	.if eax
					invoke IsDialogMessage,hWnd,addr msg
					.if !eax
						invoke TranslateMessage,addr msg
						invoke DispatchMessage,addr msg
					.endif
			  	.endif
				invoke Sleep,100
				inc		ebx
			.endw
		.endif
		invoke Sleep,500
		invoke STLinkDisconnect,hWin
		invoke DeleteObject,hFont
		invoke EndDialog,hWin,0
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

DlgProc endp

start:
	invoke	GetModuleHandle,NULL
	mov	hInstance,eax
	invoke	InitCommonControls
	mov		wc.cbSize,sizeof WNDCLASSEX
	mov		wc.style,CS_HREDRAW or CS_VREDRAW
	mov		wc.lpfnWndProc,offset FrequencyProc
	mov		wc.cbClsExtra,0
	mov		wc.cbWndExtra,0
	mov		eax,hInstance
	mov		wc.hInstance,eax
	mov		wc.hIcon,0
	invoke LoadCursor,0,IDC_ARROW
	mov		wc.hCursor,eax
	mov		wc.hbrBackground,NULL
	mov		wc.lpszMenuName,NULL
	mov		wc.lpszClassName,offset szFREQUENCYCLASS
	mov		wc.hIconSm,NULL
	invoke RegisterClassEx,addr wc
	mov		wc.lpfnWndProc,offset ScopeProc
	invoke LoadCursor,0,IDC_CROSS
	mov		wc.hCursor,eax
	mov		wc.lpszClassName,offset szSCOPECLASS
	invoke RegisterClassEx,addr wc
	invoke	DialogBoxParam,hInstance,IDD_MAIN,NULL,addr DlgProc,NULL
	invoke	ExitProcess,0

end start
