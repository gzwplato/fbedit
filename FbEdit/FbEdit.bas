
/'	FbEdit, by KetilO

	compile with:	fbc -s gui FbEdit.bas FbEdit.rc

	Licence
	-------
	FbEdit and all sources are free to use in any way you see fit.
	Sources for the custom controls used by FbEdit can be found at:
	www.radasm.com

'/

#Include Once "windows.bi"
#Include Once "win/commctrl.bi"
#Include Once "win/commdlg.bi"
#Include Once "win/richedit.bi"
#Include Once "win/shellapi.bi"
#Include Once "win/shlwapi.bi"
#Include Once "win/ole2.bi"

#Include "Inc\RAEdit.bi"
#Include "Inc\RAFile.bi"
#Include "Inc\RAProperty.bi"
#Include "Inc\RACodeComplete.bi"
#Include "Inc\RAResEd.bi"
#Include "Inc\Addins.bi"
#Include "FbEdit.bi"

#Include "IniFile.bas"
#Include "CodeComplete.bas"
#Include "Misc.bas"
#Include "FileIO.bas"
#Include "TabTool.bas"
#Include "Goto.bas"
#Include "Toolbar.bas"
#Include "About.bas"
#Include "Opt\KeyWords.bas"
#Include "Make.bas"
#Include "Opt\MenuOption.bas"
#Include "Opt\TabOptions.bas"
#Include "BlockInsert.bas"
#Include "Project.bas"
#Include "Opt\ExternalFile.bas"
#Include "Opt\PathOpt.bas"
#Include "Export.bas"
#Include "Find.bas"
#Include "Resource.bas"
#Include "Opt\DebugOpt.bas"
#Include "CreateTemplate.bas"
#Include "Addins.bas"

Function MyTimerProc(ByVal hWin As HWND,ByVal uMsg As UINT,ByVal wParam As WPARAM,ByVal lParam As LPARAM) As Integer
	Dim buffer As ZString*260
	Dim chrg As CHARRANGE
	Dim nLn As Integer
	Dim isinp As ISINPROC

	If fTimer Then
		fTimer=fTimer-1
		If fTimer=0 Then
			EnableMenu
			CheckMenu
			If ah.hred<>0 And ah.hred<>ah.hres Then
				SendMessage(ah.hred,EM_EXGETSEL,0,Cast(Integer,@chrg))
				nLn=SendMessage(ah.hred,EM_LINEFROMCHAR,chrg.cpMax,0)
				chrg.cpMin=SendMessage(ah.hred,EM_LINEINDEX,nLn,0)
				wsprintf(@buffer,@fmt,nLastLine+1,chrg.cpMax-chrg.cpMin+1)
				SetWindowText(ah.hsbr,@buffer)
				isinp.nLine=nLn
				isinp.lpszType=StrPtr("p")
				If fProject Then
					isinp.nOwner=GetProjectFileID(ah.hred)
				Else
					isinp.nOwner=Cast(Integer,ah.hred)
				EndIf
				nLn=SendMessage(ah.hpr,PRM_ISINPROC,0,Cast(LPARAM,@isinp))
				If nLn Then
					lstrcpy(@buffer,Cast(ZString ptr,nLn))
					nLn=nLn+lstrlen(Cast(ZString ptr,nLn))+1
					lstrcat(@buffer,StrPtr("("))
					lstrcat(@buffer,Cast(ZString ptr,nLn))
					lstrcat(@buffer,StrPtr(")"))
				Else
					buffer=""
				EndIf
				SendMessage(ah.hsbr,SB_SETTEXT,3,Cast(LPARAM,@buffer))
				If SendMessage(ah.hred,REM_GETMODE,0,0) And MODE_OVERWRITE Then
					SendMessage(ah.hsbr,SB_SETTEXT,1,Cast(LPARAM,StrPtr("")))
				Else
					SendMessage(ah.hsbr,SB_SETTEXT,1,Cast(LPARAM,StrPtr("  INS")))
				EndIf
			EndIf
			UpdateAllTabs(3)
			UpdateAllTabs(4)
		EndIf
	EndIf
	If nHideOut Then
		nHideOut=nHideOut-1
		If nHideOut=0 Then
			ShowOutput(FALSE)
		EndIf
	EndIf
	If (GetKeyState(VK_CONTROL) And &H80)=0 Then
		nLn=SendMessage(ah.htabtool,TCM_GETCURSEL,0,0)
		If nLn<>curtab Then
			prevtab=curtab
			curtab=nLn
		EndIf
	EndIf
	If nSplash Then
		nSplash=nSplash-1
		If nsplash=0 Then
			DestroyWindow(GetDlgItem(ah.hwnd,IDC_IMGSPLASH))
			DeleteObject(hSplashBmp)
		EndIf
	EndIf
	If fChangeNotification=0 Then
		UpdateAllTabs(5)
		fChangeNotification=10
	Else
		fChangeNotification-=1
	EndIf
	Return 0

End Function

Function FullScreenProc(ByVal hWin As HWND,ByVal uMsg As UINT,ByVal wParam As WPARAM,ByVal lParam As LPARAM) As Integer
	Dim hCld As HWND

	Select Case uMsg
		Case WM_DESTROY
			ah.hfullscreen=0
			hCld=GetWindow(hWin,GW_CHILD)
			SetParent(hCld,ah.hwnd)
			SetFocus(hCld)
			fInUse=0
	End Select
	Return DefWindowProc(hWin,uMsg,wParam,lParam)

End Function

Sub CmdLine
	Dim x As Integer

	s=String(16384,szNULL)
	buff=String(16384,szNULL)
	lstrcpyn(@s,CommandLine,8192)
	''' skip whites space
	''' test ltrim for speed 
	Do While (Asc(s)=Asc(" ")) Or (Asc(s)=9)
		''' avoid mid
		''' better use a index
		s=Mid(s,2)
	Loop
	If Len(s) Then
		s=s & " "
	ElseIf edtopt.autoload Then
		' Load last project
		SendMessage(ah.hwnd,WM_COMMAND,14001,0)
		s=""
	EndIf
	x=1
	Do While Asc(s,x)<>0 ''' szNULL
		If Asc(s,x)=34 Then
			x=x+1
			Do While Asc(s,x)<>34
				x=x+1
			Loop
		EndIf
		If Asc(s,x)=Asc(" ") Then
			lstrcpyn(@ad.filename,@s,x)
			If Asc(ad.filename)=34 Then
				ad.filename=Mid(ad.filename,2,InStr(2,ad.filename,Chr(34))-2)
			EndIf
			' Open single file
			OpenTheFile(ad.filename)
			s=Mid(s,x+1)
			x=0
		EndIf
		x=x+1
	Loop

End Sub

Function SplashProc(ByVal hWin As HWND,ByVal uMsg As UINT,ByVal wParam As WPARAM,ByVal lParam As LPARAM) As Integer
	Dim ps As PAINTSTRUCT
	Dim mDC As HDC
	Dim rect As RECT

	Select Case uMsg
		Case WM_PAINT
			GetClientRect(hWin,@rect)
			BeginPaint(hWin,@ps)
			mDC=CreateCompatibleDC(ps.hdc)
			SelectObject(mDC,hSplashBmp)
			StretchBlt(ps.hdc,0,0,rect.right,rect.bottom,mDC,0,0,340,188,SRCCOPY)
			FrameRect(ps.hdc,@rect,GetStockObject(BLACK_BRUSH))
			EndPaint(hWin,@ps)
			Return 0
			'
		Case Else
			Return CallWindowProc(lpOldSplashProc,hWin,uMsg,wParam,lParam)
	End Select

End Function

Function DlgProc(ByVal hWin As HWND,ByVal uMsg As UINT,ByVal wParam As WPARAM,ByVal lParam As LPARAM) As Integer
	Dim As Long id,x,y,lret,bm,hgt,wdt,tbhgt,twt,prjht,prht,i
	Dim rect As RECT
	Dim rect1 As RECT
	Dim chrg As CHARRANGE
	Dim lpRASELCHANGE As RASELCHANGE ptr
	Dim lpTOOLTIPTEXT As TOOLTIPTEXT ptr
	Dim lpFBNOTIFY As FBNOTIFY ptr
	Dim lpRAPNOTIFY As RAPNOTIFY ptr
	Dim lpNMTVDISPINFO As NMTVDISPINFO ptr
	Dim hCtl As HWND
	Dim lfnt As LOGFONT
	Dim tci As TCITEM
	Dim lpTABMEM As TABMEM ptr
	Dim nLine As Integer
	Dim hBmp As HBITMAP
	Dim sItem As ZString*260
	Dim wcex As WNDCLASSEXA
	Dim lpRESMEM As RESMEM ptr
	Dim hMem As HGLOBAL
	Dim lpCOPYDATASTRUCT As COPYDATASTRUCT ptr
	Dim sbParts(3) As Integer
	Dim sFile As String
	Dim pt As Point
	Dim hMnu As HMENU

	Select Case uMsg
		Case WM_INITDIALOG
			ah.hwnd=hWin
			ad.lpFBCOLOR=@fbcol
			ad.lpWINPOS=@wpos
			' Shape
			ah.hshp=GetDlgItem(hWin,IDC_SHP)
			' Statusbar
			ah.hsbr=GetDlgItem(hWin,IDC_STATUSBAR)
			sbParts(0)=225				' pixels from left
			sbParts(1)=260				' pixels from left
			sbParts(2)=400				' pixels from left
			sbParts(3)=-1				' last part
			SendMessage(ah.hsbr,SB_SETPARTS,4,Cast(Integer,@sbParts(0)))
			' Set close button image
			SendDlgItemMessage(hWin,IDM_FILE_CLOSE,BM_SETIMAGE,IMAGE_BITMAP,Cast(Integer,LoadBitmap(hInstance,Cast(ZString ptr,101))))
			' Get from ini
			GetPrivateProfileString(StrPtr("Project"),StrPtr("Path"),StrPtr("\"),@ad.DefProjectPath,SizeOf(ad.DefProjectPath),@ad.IniFile)
			If Asc(ad.DefProjectPath)=Asc("\") Then
				ad.DefProjectPath=Left(ad.AppPath,2) & ad.DefProjectPath
			EndIf
			GetPrivateProfileString(StrPtr("Make"),StrPtr("fbcPath"),@szNULL,@ad.fbcPath,SizeOf(ad.fbcPath),@ad.IniFile)
			If Asc(ad.fbcPath)=Asc("\") Then
				ad.fbcPath=Left(ad.AppPath,2) & ad.fbcPath
			EndIf
			LoadFromIni(StrPtr("Resource"),StrPtr("Export"),"4440",@nmeexp,FALSE)
			LoadFromIni(StrPtr("Resource"),StrPtr("Grid"),"444444444",@grdsize,FALSE)
			LoadFromIni(StrPtr("Win"),StrPtr("Colors"),"4444444444444444444444444",@fbcol,FALSE)
			LoadFromIni(StrPtr("Edit"),StrPtr("Colors"),"44444444444444444",@kwcol,FALSE)
			LoadFromIni(StrPtr("Edit"),StrPtr("CustColors"),"44444444444444444",@custcol,FALSE)
			' Get handle of build combobox
			ah.hcbobuild=GetDlgItem(hWin,IDC_CBOBUILD)
			' Get handle of find in page edit
			ah.hfindinpage=GetDlgItem(hWin,IDC_FINDINPAGE)
			' Get make option from ini
			GetMakeOption
			' Get CodeFiles from ini
			GetPrivateProfileString(StrPtr("Edit"),StrPtr("CodeFiles"),StrPtr(".bas.bi."),@sCodeFiles,SizeOf(sCodeFiles),@ad.IniFile)
			' Get debug from ini
			GetPrivateProfileString(StrPtr("Debug"),StrPtr("Debug"),@szNULL,@ad.smakerundebug,SizeOf(ad.smakerundebug),@ad.IniFile)
			' Get case convert
			GetPrivateProfileString(StrPtr("Edit"),StrPtr("CaseConvert"),StrPtr("CWPp"),@szCaseConvert,SizeOf(szCaseConvert),@ad.IniFile)
			' Get handle of ToolBar control
			ad.tbwt=670
			ah.htoolbar=GetDlgItem(hWin,IDC_TOOLBAR)
			DoToolbar(ah.htoolbar,hInstance)
			' Handle of tabs
			ah.htabtool=GetDlgItem(hWin,IDC_TABSELECT)
			lpOldTabToolProc=Cast(Any ptr,SetWindowLong(ah.htabtool,GWL_WNDPROC,Cast(Integer,@TabToolProc)))
			' Handle of output window
			ah.hout=GetDlgItem(hWin,IDC_OUTPUT)
			lpOldOutputProc=Cast(Any ptr,SetWindowLong(ah.hout,GWL_WNDPROC,Cast(Integer,@OutputProc)))
			hDlgFnt=Cast(HFONT,SendMessage(ah.htabtool,WM_GETFONT,0,0))
			LoadFromIni(StrPtr("Edit"),StrPtr("EditOpt"),"4444444444444444",@edtopt,FALSE)
			' Create fonts
			LoadFromIni(StrPtr("Edit"),StrPtr("EditFont"),"440",@edtfnt,FALSE)
			lfnt.lfHeight=edtfnt.size
			lfnt.lfCharSet=edtfnt.charset
			lstrcpy(lfnt.lfFaceName,edtfnt.szFont)
			lfnt.lfItalic=0
			ah.rafnt.hFont=CreateFontIndirect(@lfnt)
			lfnt.lfItalic=1
			ah.rafnt.hIFont=CreateFontIndirect(@lfnt)
			LoadFromIni(StrPtr("Edit"),StrPtr("LnrFont"),"440",@lnrfnt,FALSE)
			lfnt.lfHeight=lnrfnt.size
			lfnt.lfCharSet=lnrfnt.charset
			lstrcpy(lfnt.lfFaceName,lnrfnt.szFont)
			lfnt.lfItalic=0
			ah.rafnt.hLnrFont=CreateFontIndirect(@lfnt)
			' Font for output window
			lfnt.lfHeight=-11
			lfnt.lfCharSet=edtfnt.charset
			lstrcpy(lfnt.lfFaceName,StrPtr("Courier New"))
			lfnt.lfItalic=0
			ah.hOutFont=CreateFontIndirect(@lfnt)
			SendMessage(ah.hout,WM_SETFONT,Cast(WPARAM,ah.hOutFont),FALSE)
			' Turn off default comment char
			SendMessage(ah.hout,REM_SETCHARTAB,Asc(";"),CT_OPER)
			' Define @ as a operand
			SendMessage(ah.hout,REM_SETCHARTAB,Asc("@"),CT_OPER)
			' Define # as a character
			SendMessage(ah.hout,REM_SETCHARTAB,Asc("#"),CT_CHAR)
			' Set comment char
			SendMessage(ah.hout,REM_SETCHARTAB,Asc("'"),CT_CMNTCHAR)
			' Set comment block init char
			SendMessage(ah.hout,REM_SETCHARTAB,Asc("/"),CT_CMNTINITCHAR)
			' Set comment block definition
			SendMessage(ah.hout,REM_SETCOMMENTBLOCKS,Cast(Integer,StrPtr("/'")),Cast(Integer,StrPtr("'/")))
			' Set code blocks
			i=0
			While i<31
				blk.lpszStart=@szSt(i)
				blk.lpszEnd=@szEn(i)
				blk.lpszNot1=@szNot1
				blk.lpszNot2=@szNot2
				If LoadFromIni(StrPtr("Block"),Str(i),"00004",@blk,FALSE) Then
					If Len(szSt(i)) Then
						BD(i).lpszStart=@szSt(i)
					EndIf
					If Len(szEn(i)) Then
						BD(i).lpszEnd=@szEn(i)
					EndIf
					If Len(szNot1) Then
						BD(i).lpszNot1=@szNot1
					EndIf
					If Len(szNot2) Then
						BD(i).lpszNot2=@szNot2
					EndIf
					BD(i).flag=blk.flag
					SendMessage(ah.hout,REM_ADDBLOCKDEF,0,Cast(Integer,@BD(i)))
					x=InStr(szEn(i),"|")
					If x Then
						Mid(szEn(i),x,1)=szNULL
					EndIf
				EndIf
				autofmt(i).wrd=@szIndent(i)
				LoadFromIni(StrPtr("AutoFormat"),Str(i),"0444",@autofmt(i),FALSE)
				i=i+1
			Wend
			' Set bracket matching
			If edtopt.bracematch Then
				SendMessage(ah.hout,REM_BRACKETMATCH,0,Cast(Integer,@szBracketMatch))
			Else
				SendMessage(ah.hout,REM_BRACKETMATCH,0,Cast(Integer,StrPtr("")))
			EndIf
			' Menus
			ah.hmenu=GetMenu(hWin)
			ah.hcontextmenu=LoadMenu(hInstance,Cast(ZString ptr,IDR_CONTEXTMENU))
			' Project tab
			ah.htab=GetDlgItem(hWin,IDC_TAB)
			tci.mask=TCIF_TEXT
			tci.pszText=StrPtr("File")
			SendMessage(ah.htab,TCM_INSERTITEM,999,Cast(Integer,@tci))
			tci.pszText=StrPtr("Project")
			SendMessage(ah.htab,TCM_INSERTITEM,999,Cast(Integer,@tci))
			' Project browser
			ah.hprj=GetDlgItem(hWin,IDC_TRVPRJ)
			lpOldProjectProc=Cast(Any ptr,SetWindowLong(ah.hprj,GWL_WNDPROC,Cast(Integer,@ProjectProc)))
			' Create the imagelist
			ah.himl=ImageList_Create(16,16,ILC_MASK Or ILC_COLOR8,16,0)
			hBmp=LoadBitmap(hInstance,Cast(ZString ptr,IDB_FILES))
			ImageList_AddMasked(ah.himl,hBmp,&HFF00FF)
			DeleteObject(hBmp)
			SendMessage(ah.hprj,TVM_SETIMAGELIST,TVSIL_NORMAL,Cast(Integer,ah.himl))
			SendMessage(ah.htabtool,TCM_SETIMAGELIST,0,Cast(Integer,ah.himl))
			' Setup filebrowser
			ah.hfib=GetDlgItem(hWin,IDC_FILEBROWSER)
			SendMessage(ah.hfib,FBM_SETPATH,FALSE,Cast(Integer,@ad.DefProjectPath))
			SendMessage(ah.hfib,FBM_SETFILTERSTRING,FALSE,Cast(Integer,StrPtr(".bas.bi.rc.txt.fbp.")))
			SendMessage(ah.hfib,FBM_SETFILTER,TRUE,TRUE)
			' Property definitions
			ah.hpr=GetDlgItem(hWin,IDC_PROPERTY)
			SendMessage(ah.hpr,PRM_SETCHARTAB,0,Cast(LPARAM,ad.lpCharTab))
			SendMessage(ah.hpr,PRM_SETGENDEF,0,Cast(Integer,@defgen))
			' Lines to skip
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_LINEFIRSTWORD,Cast(Integer,StrPtr("declare")))
			' Words to skip
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_FIRSTWORD,Cast(Integer,StrPtr("private")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_FIRSTWORD,Cast(Integer,StrPtr("public")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_SECONDWORD,Cast(Integer,StrPtr("shared")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_DATATYPEINIT,Cast(Integer,StrPtr("as")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_PROCPARAM,Cast(Integer,StrPtr("byval")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_PROCPARAM,Cast(Integer,StrPtr("byref")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_PROCPARAM,Cast(Integer,StrPtr("alias")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_PROCPARAM,Cast(Integer,StrPtr("cdecl")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_STRUCTITEMFIRSTWORD,Cast(Integer,StrPtr("as")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_STRUCTITEMSECONDWORD,Cast(Integer,StrPtr("as")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_STRUCTTHIRDWORD,Cast(Integer,StrPtr("as")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_STRUCTITEMINIT,Cast(Integer,StrPtr("declare")))
			SendMessage(ah.hpr,PRM_ADDIGNORE,IGNORE_PTR,Cast(Integer,StrPtr("ptr")))
			' Property types
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("p")+256,Cast(Integer,StrPtr(szCode)))
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("c"),Cast(Integer,StrPtr(szConst)))
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("d")+512,Cast(Integer,StrPtr(szData)))
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("s"),Cast(Integer,StrPtr(szStruct)))
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("e"),Cast(Integer,StrPtr(szEnum)))
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("n"),Cast(Integer,StrPtr(szNamespace)))
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("m"),Cast(Integer,StrPtr(szMacro)))
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("x")+256,Cast(Integer,StrPtr(szConstructor)))
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("y")+256,Cast(Integer,StrPtr(szDestructor)))
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("z")+256,Cast(Integer,StrPtr(szProperty)))
			SendMessage(ah.hpr,PRM_ADDPROPERTYTYPE,Asc("o")+256,Cast(Integer,StrPtr(szOperator)))
			' Parse defs
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypesub))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendsub))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypefun))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendfun))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypedata))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypecommon))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypestatic))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypevar))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeconst))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeconst2))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypestruct))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendstruct))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeunion))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendunion))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeenum))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendenum))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypenamespace))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendnamespace))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypewithblock))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendwithblock))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypemacro))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendmacro))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeconstructor))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendconstructor))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypedestructor))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeenddestructor))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeproperty))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendproperty))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeoperator))
			SendMessage(ah.hpr,PRM_ADDDEFTYPE,0,Cast(Integer,@deftypeendoperator))
			' Set cbo selection
			SendMessage(ah.hpr,PRM_SELECTPROPERTY,Asc("p")+256,0)
			' Set button 'Open files'
			SendMessage(ah.hpr,PRM_SETSELBUTTON,2,0)
			' Code complete list
			ah.hcc=CreateWindowEx(NULL,@szCCLBClassName,NULL,WS_POPUP Or WS_THICKFRAME Or WS_CLIPSIBLINGS Or WS_CLIPCHILDREN Or STYLE_USEIMAGELIST,0,0,wpos.ptcclist.x,wpos.ptcclist.y,hWin,NULL,hInstance,0)
			lpOldCCProc=Cast(Any ptr,SetWindowLong(ah.hcc,GWL_WNDPROC,Cast(Integer,@CCProc)))
			SendMessage(ah.hcc,WM_SETFONT,Cast(Integer,hDlgFnt),0)
			' Code complete tooltip
			ah.htt=CreateWindowEx(NULL,@szCCTTClassName,NULL,WS_POPUP Or WS_BORDER Or WS_CLIPSIBLINGS Or WS_CLIPCHILDREN Or STYLE_USEPARANTESES,0,0,0,0,hWin,NULL,hInstance,0)
			SendMessage(ah.htt,WM_SETFONT,Cast(Integer,hDlgFnt),0)
			' Position and size main window
			SetWindowPos(hWin,NULL,wpos.x,wpos.y,wpos.wt,wpos.ht,SWP_NOZORDER)
			If wpos.fmax Then
				ShowWindow(hWin,SW_MAXIMIZE)
			EndIf
			If wpos.fview And VIEW_OUTPUT Then
				ShowWindow(ah.hout,SW_SHOWNA)
				SendMessage(ah.htoolbar,TB_CHECKBUTTON,IDM_VIEW_OUTPUT,TRUE)
			EndIf
			If wpos.fview And VIEW_PROJECT Then
				ShowWindow(ah.htab,SW_SHOWNA)
				ShowWindow(ah.hfib,SW_SHOWNA)
				SendMessage(ah.htoolbar,TB_CHECKBUTTON,IDM_VIEW_PROJECT,TRUE)
			EndIf
			If wpos.fview And VIEW_PROPERTY Then
				ShowWindow(ah.hpr,SW_SHOWNA)
				SendMessage(ah.htoolbar,TB_CHECKBUTTON,IDM_VIEW_PROPERTY,TRUE)
			EndIf
			GetPrivateProfileString(StrPtr("Api"),StrPtr("Api"),@szNULL,@ApiFiles,SizeOf(ApiFiles),@ad.IniFile)
			GetPrivateProfileString(StrPtr("Api"),StrPtr("DefApi"),@szNULL,@DefApiFiles,SizeOf(DefApiFiles),@ad.IniFile)
			SetHiliteWords(ah.hwnd)
			' Add api files
			LoadApiFiles
			SetHiliteWordsFromApi(ah.hwnd)
			ah.hmnuiml=ImageList_Create(16,16,ILC_COLOR4 Or ILC_MASK,4,0)
			hBmp=LoadBitmap(hInstance,Cast(ZString ptr,IDB_MNUARROW))
			ImageList_AddMasked(ah.hmnuiml,hBmp,&HC0C0C0)
			DeleteObject(hBmp)
			' Create a class for the resource editor
			wcex.cbSize=SizeOf(WNDCLASSEXA)
			wcex.style=CS_HREDRAW Or CS_VREDRAW
			wcex.lpfnWndProc=@ResProc
			wcex.cbClsExtra=0
			wcex.cbWndExtra=4
			wcex.hInstance=hInstance
			wcex.hbrBackground=Cast(HBRUSH,COLOR_BTNFACE+1)
			wcex.lpszMenuName=NULL
			wcex.lpszClassName=@szResClassName
			wcex.hIcon=0
			wcex.hIconSm=0
			wcex.hCursor=LoadCursor(NULL,IDC_ARROW)
			RegisterClassEx(@wcex)
			' Full screen
			wcex.cbSize=SizeOf(WNDCLASSEXA)
			wcex.style=CS_HREDRAW Or CS_VREDRAW
			wcex.lpfnWndProc=@FullScreenProc
			wcex.cbClsExtra=NULL
			wcex.cbWndExtra=NULL
			wcex.hInstance=hInstance
			wcex.hbrBackground=Cast(HBRUSH,NULL)
			wcex.lpszMenuName=NULL
			wcex.lpszClassName=@szFullScreenClassName
			wcex.hIcon=0
			wcex.hCursor=LoadCursor(NULL,IDC_ARROW)
			wcex.hIconSm=0
			RegisterClassEx(@wcex)
			ah.hres=CreateWindowEx(0,@szResClassName,NULL,WS_CHILD Or WS_VISIBLE Or WS_CLIPSIBLINGS Or WS_CLIPCHILDREN,0,0,0,0,hWin,Cast(HMENU,IDC_RESED),hInstance,0)
			SetToolsColors(hWin)
			SetToolMenu(hWin)
			SetHelpMenu(hWin)
			SetTimer(hWin,200,200,Cast(Any ptr,@MyTimerProc))
			SetWinCaption
			hVCur=LoadCursor(hInstance,Cast(ZString ptr,IDC_VSPLIT))
			hHCur=LoadCursor(hInstance,Cast(ZString ptr,IDC_HSPLIT))
			OpenMruProjects
			OpenMruFiles
			fTimer=1
			LoadAddins
			ShowWindow(ah.htabtool,SW_HIDE)
			hSplashBmp=LoadBitmap(hInstance,Cast(ZString ptr,103))
			lpOldSplashProc=Cast(Any ptr,SetWindowLong(GetDlgItem(hWin,IDC_IMGSPLASH),GWL_WNDPROC,Cast(Integer,@SplashProc)))
			SetFocus(hWin)
			Return FALSE
			'
		Case WM_CLOSE
			If CloseAllTabs(hWin,fProject,0)=FALSE Then
				If CallAddins(hWin,AIM_CLOSE,wParam,lParam,HOOK_CLOSE) Then
					Return 0
				EndIf
				GetWindowRect(hWin,@rect)
				If IsIconic(hWin)=FALSE And IsZoomed(hWin)=FALSE Then
					wpos.x=rect.left
					wpos.y=rect.top
					wpos.wt=rect.right-rect.left
					wpos.ht=rect.bottom-rect.top
				EndIf
				wpos.fmax=IsZoomed(hWin)
				lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hres,0))
				SendMessage(lpRESMEM->hProject,PRO_GETSTYLEPOS,0,Cast(Integer,@wpos.ptstyle))
				GetWindowRect(ah.hcc,@rect)
				wpos.ptcclist.x=rect.right-rect.left
				wpos.ptcclist.y=rect.bottom-rect.top
				DestroyWindow(ah.hcc)
				DestroyWindow(ah.htt)
				DestroyWindow(lpRESMEM->hResEd)
				DestroyWindow(lpRESMEM->hProject)
				DestroyWindow(lpRESMEM->hProperty)
				DestroyWindow(lpRESMEM->hToolBox)
				DestroyWindow(ah.hres)
				Return DefWindowProc(hWin,uMsg,wParam,lParam)
			EndIf
			'
		Case WM_DESTROY
			KillTimer(hWin,200)
			DeleteObject(Cast(HBITMAP,SendDlgItemMessage(hWin,IDM_FILE_CLOSE,BM_SETIMAGE,IMAGE_BITMAP,0)))
			DeleteObject(ah.rafnt.hFont)
			DeleteObject(ah.rafnt.hIFont)
			DeleteObject(ah.rafnt.hLnrFont)
			DeleteObject(ah.hOutFont)
			DestroyIcon(hIcon)
			DestroyCursor(hVCur)
			DestroyCursor(hHCur)
			ImageList_Destroy(ah.hmnuiml)
			ImageList_Destroy(ah.himl)
			DestroyMenu(ah.hcontextmenu)
			SaveToIni(StrPtr("Win"),StrPtr("Winpos"),"4444444444444444444",@wpos,FALSE)
			DefWindowProc(hWin,uMsg,wParam,lParam)
			PostQuitMessage(NULL)
			'
		Case WM_COMMAND
			If CallAddins(hWin,AIM_COMMAND,wParam,lParam,HOOK_COMMAND) Then
				Return 0
			EndIf
			id=LoWord(wParam)
			Select Case HiWord(wParam)
				Case EN_CHANGE
					If id=IDC_FINDINPAGE Then
						SetHiliteWordFindInPage(ah.hwnd)
					EndIf
				Case BN_CLICKED,1
					Select Case id
						Case IDM_FILE_NEWPROJECT
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_NEWPROJECT),GetOwner,@NewProjectDlgProc,NULL)
							fTimer=1
							'
						Case IDM_FILE_OPENPROJECT
							If OpenAProject(hWin) Then
								fTimer=1
							EndIf
							'
						Case IDM_FILE_CLOSEPROJECT
							CloseProject
							fTimer=1
							'
						Case IDM_FILE_NEW
							ad.filename="(Untitled).bas"
							ah.hred=CreateEdit(hWin)
							AddTab(hWin,ah.hred,ad.filename)
							If SendMessage(ah.hpr,PRM_GETSELBUTTON,0,0)=1 Then
								UpdateFileProperty
							EndIf
							'
						Case IDM_FILE_NEW_RESOURCE
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hres,0))
							ad.filename="(Untitled).rc"
							hMem=MyGlobalAlloc(GMEM_FIXED Or GMEM_ZEROINIT,4096)
							GlobalLock(hMem)
							SendMessage(lpRESMEM->hProject,PRO_OPEN,Cast(Integer,@ad.filename),Cast(Integer,hMem))
							ShowWindow(ah.hred,SW_HIDE)
							ah.hred=ah.hres
							AddTab(hWin,ah.hred,ad.filename)
							SetWinCaption
							ShowWindow(ah.hred,SW_SHOW)
							SendMessage(hWin,WM_SIZE,0,0)
							SetFocus(ah.hred)
							'
						Case IDM_FILE_OPEN
							buff=OpenInclude
							If Len(buff) Then
								OpenTheFile(buff)
							Else
								OpenAFile(hWin)
							EndIf
							If SendMessage(ah.hpr,PRM_GETSELBUTTON,0,0)=1 Then
								UpdateFileProperty
							EndIf
							'
						Case IDM_FILE_SAVE
							If ah.hred Then
								SetFocus(ah.hred)
								If Left(ad.filename,10)="(Untitled)" Then
									SaveFileAs(hWin)
								Else
									WriteTheFile(ah.hred,ad.filename)
								EndIf
								UpdateAllTabs(4)
							EndIf
							'
						Case IDM_FILE_SAVEALL
							If ah.hred Then
								SaveAllFiles(hWin)
								UpdateAllTabs(4)
							EndIf
							'
						Case IDM_FILE_SAVEAS
							If ah.hred Then
								SaveFileAs(hWin)
								UpdateAllTabs(4)
							EndIf
							'
						Case IDM_FILE_CLOSE
							If ah.hred Then
								If WantToSave(hWin)=FALSE Then
									DelTab(hWin)
								EndIf
								If SendMessage(ah.hpr,PRM_GETSELBUTTON,0,0)=1 Then
									UpdateFileProperty
								EndIf
								fTimer=1
							EndIf
							'
						Case IDM_FILE_CLOSEALL
							If ah.hred Then
								If CloseAllTabs(hWin,FALSE,0)=FALSE Then
									'
								EndIf
								If SendMessage(ah.hpr,PRM_GETSELBUTTON,0,0)=1 Then
									UpdateFileProperty
								EndIf
								fTimer=1
							EndIf
							'
						Case IDM_FILE_EXIT
							SendMessage(hWin,WM_CLOSE,0,0)
							'
						Case IDM_EDIT_UNDO
							SendMessage(ah.hred,EM_UNDO,0,0)
							'
						Case IDM_EDIT_REDO
							SendMessage(ah.hred,EM_REDO,0,0)
							'
						Case IDM_EDIT_CUT
							SendMessage(ah.hred,WM_CUT,0,0)
							'
						Case IDM_EDIT_COPY
							SendMessage(ah.hred,WM_COPY,0,0)
							'
						Case IDM_EDIT_PASTE
							SendMessage(ah.hred,WM_PASTE,0,0)
							'
						Case IDM_EDIT_DELETE
							SendMessage(ah.hred,WM_CLEAR,0,0)
							'
						Case IDM_EDIT_SELECTALL
							chrg.cpMin=0
							chrg.cpMax=-1
							SendMessage(ah.hred,EM_EXSETSEL,0,Cast(Integer,@chrg))
							'
						Case IDM_EDIT_GOTO
							If gotovisible Then
								SetFocus(gotovisible)
							Else
								CreateDialogParam(hInstance,Cast(ZString ptr,IDD_GOTODLG),GetOwner,@GotoDlgProc,0)
							EndIf
							'
						Case IDM_EDIT_FIND
							SendMessage(ah.hred,EM_EXGETSEL,0,Cast(LPARAM,@chrg))
							If chrg.cpMin<>chrg.cpMax Then
								SendMessage(ah.hred,EM_GETSELTEXT,0,Cast(LPARAM,@buff))
							Else
								SendMessage(ah.hred,REM_GETWORD,260,Cast(LPARAM,@buff))
							EndIf
							If Len(buff) Then
								findbuff=buff
							EndIf
							If findvisible Then
								SendDlgItemMessage(ah.hfind,IDC_FINDTEXT,WM_SETTEXT,0,Cast(LPARAM,@findbuff))
								SetFocus(findvisible)
							Else
								CreateDialogParam(hInstance,Cast(ZString ptr,IDD_FINDDLG),GetOwner,@FindDlgProc,FALSE)
							EndIf
							'
						Case IDM_EDIT_FINDNEXT
							Find(hWin,fr Or FR_DOWN)
							'
						Case IDM_EDIT_FINDPREVIOUS
							Find(hWin,fr And (-1 Xor FR_DOWN))
							'
						Case IDM_EDIT_REPLACE
							SendMessage(ah.hred,EM_EXGETSEL,0,Cast(LPARAM,@chrg))
							If chrg.cpMin<>chrg.cpMax Then
								SendMessage(ah.hred,EM_GETSELTEXT,0,Cast(LPARAM,@buff))
							Else
								SendMessage(ah.hred,REM_GETWORD,260,Cast(LPARAM,@buff))
							EndIf
							If Len(buff) Then
								findbuff=buff
							EndIf
							If findvisible Then
								SetFocus(findvisible)
							Else
								CreateDialogParam(hInstance,Cast(ZString ptr,IDD_FINDDLG),GetOwner,@FindDlgProc,TRUE)
							EndIf
							'
						Case IDM_EDIT_FINDDECLARE
							SendMessage(ah.hred,REM_GETWORD,260,Cast(Integer,@buff))
							lret=Cast(Integer,FindExact(StrPtr("pdcs"),@buff,TRUE))
							If lret Then
								hCtl=ah.hred
								SendMessage(ah.hred,EM_EXGETSEL,0,Cast(Integer,@chrg))
								nLine=chrg.cpMin
								lret=SendMessage(ah.hpr,PRM_FINDGETOWNER,0,0)
								If fProject Then
									OpenProjectFile(lret)
								Else
									SelectTab(hWin,Cast(HWND,lret),0)
								EndIf
								lret=SendMessage(ah.hpr,PRM_FINDGETLINE,0,0)
								chrg.cpMin=SendMessage(ah.hred,EM_LINEINDEX,lret,0)
								chrg.cpMax=chrg.cpMin
								SendMessage(ah.hred,EM_EXSETSEL,0,Cast(Integer,@chrg))
								SendMessage(ah.hred,EM_SCROLLCARET,0,0)
								SendMessage(ah.hred,REM_VCENTER,0,0)
								SetFocus(ah.hred)
								fdcpos=(fdcpos+1) And 15
								fdc(fdcpos).npos=nLine
								fdc(fdcpos).hwnd=hCtl
							EndIf
							fTimer=1
							'
						Case IDM_EDIT_RETURN
							If IsWindow(fdc(fdcpos).hwnd) Then
								SelectTab(hWin,fdc(fdcpos).hwnd,0)
								chrg.cpMin=fdc(fdcpos).npos
								chrg.cpMax=chrg.cpMin
								SendMessage(ah.hred,EM_EXSETSEL,0,Cast(Integer,@chrg))
								SendMessage(ah.hred,EM_SCROLLCARET,0,0)
								SetFocus(ah.hred)
							EndIf
							If fdcpos Then
								fdcpos=fdcpos-1
							Else
								fdcpos=15
							EndIf
							fTimer=1
							'
						Case IDM_EDIT_BLOCKINDENT
							IndentComment(Chr(9),FALSE)
							'
						Case IDM_EDIT_BLOCKOUTDENT
							IndentComment(Chr(9),TRUE)
							'
						Case IDM_EDIT_BLOCKCOMMENT
							IndentComment("'" & szNULL,FALSE)
							'
						Case IDM_EDIT_BLOCKUNCOMMENT
							IndentComment("'" & szNULL,TRUE)
							'
						Case IDM_EDIT_BLOCKTRIM
							TrimTrailingSpaces
							'
						Case IDM_EDIT_CONVERTTAB
							SendMessage(ah.hred,REM_CONVERT,CONVERT_TABTOSPACE,0)
							'
						Case IDM_EDIT_CONVERTSPACE
							SendMessage(ah.hred,REM_CONVERT,CONVERT_SPACETOTAB,0)
							'
						Case IDM_EDIT_CONVERTUPPER
							SendMessage(ah.hred,REM_CONVERT,CONVERT_UPPERCASE,0)
							'
						Case IDM_EDIT_CONVERTLOWER
							SendMessage(ah.hred,REM_CONVERT,CONVERT_LOWERCASE,0)
							'
						Case IDM_EDIT_BLOCKMODE
							bm=SendMessage(ah.hred,REM_GETMODE,0,0) Xor MODE_BLOCK
							SendMessage(ah.hred,REM_SETMODE,bm,0)
							'
						Case IDM_EDIT_BLOCK_INSERT
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_BLOCKDLG),GetOwner,@BlockDlgProc,NULL)
							'
						Case IDM_EDIT_BOOKMARKTOGGLE
							lret=SendMessage(ah.hred,REM_GETBOOKMARK,nLastLine,0)
							If lret=0 Then
								SendMessage(ah.hred,REM_SETBOOKMARK,nLastLine,3)
							ElseIf lret=3 Then
								SendMessage(ah.hred,REM_SETBOOKMARK,nLastLine,0)
							EndIf
							fTimer=1
							'
						Case IDM_EDIT_BOOKMARKNEXT
							nLine=SendMessage(ah.hred,REM_NXTBOOKMARK,nLastLine,3)
							If nLine<>-1 Then
								chrg.cpMin=SendMessage(ah.hred,EM_LINEINDEX,nLine,0)
								chrg.cpMax=chrg.cpMin
								SendMessage(ah.hred,EM_EXSETSEL,0,Cast(Integer,@chrg))
								SendMessage(ah.hred,EM_SCROLLCARET,0,0)
							EndIf
							'
						Case IDM_EDIT_BOOKMARKPREVIOUS
							nLine=SendMessage(ah.hred,REM_PRVBOOKMARK,nLastLine,3)
							If nLine<>-1 Then
								chrg.cpMin=SendMessage(ah.hred,EM_LINEINDEX,nLine,0)
								chrg.cpMax=chrg.cpMin
								SendMessage(ah.hred,EM_EXSETSEL,0,Cast(Integer,@chrg))
								SendMessage(ah.hred,EM_SCROLLCARET,0,0)
							EndIf
							'
						Case IDM_EDIT_BOOKMARKDELETE
							SendMessage(ah.hred,REM_CLRBOOKMARKS,0,3)
							fTimer=1
							'
						Case IDM_EDIT_ERRORCLEAR
							UpdateAllTabs(2)
							fTimer=1
							'
						Case IDM_EDIT_ERRORNEXT
							nLine=SendMessage(ah.hred,REM_NXTBOOKMARK,nLastLine,7)
							If nLine=-1 Then
								nLine=SendMessage(ah.hred,REM_NXTBOOKMARK,-1,7)
							EndIf
							If nLine<>-1 Then
								chrg.cpMin=SendMessage(ah.hred,EM_LINEINDEX,nLine,0)
								chrg.cpMax=chrg.cpMin
								SendMessage(ah.hred,EM_EXSETSEL,0,Cast(Integer,@chrg))
								SendMessage(ah.hred,EM_SCROLLCARET,0,0)
							EndIf
							'
						Case IDM_EDIT_EXPAND
							SendMessage(ah.hred,EM_EXGETSEL,0,Cast(LPARAM,@chrg))
							i=SendMessage(ah.hred,EM_EXLINEFROMCHAR,0,chrg.cpMin)
							bm=SendMessage(ah.hred,REM_GETBOOKMARK,i,0)
							If bm=1 Then
								' Collapse
								SendMessage(ah.hred,REM_COLLAPSE,i,0)
							ElseIf bm=2 Then
								' Expand
								SendMessage(ah.hred,REM_EXPAND,i,0)
							ElseIf SendMessage(ah.hred,REM_ISLINEHIDDEN,i+1,0) Then
								While SendMessage(ah.hred,REM_ISLINEHIDDEN,i+1,0)
									SendMessage(ah.hred,REM_HIDELINE,i+1,FALSE)
									i=i+1
								Wend
								SendMessage(ah.hred,REM_REPAINT,0,0)
							ElseIf SendMessage(ah.hred,REM_ISLINEHIDDEN,i-1,0)<>0 Or SendMessage(ah.hred,REM_GETBOOKMARK,i-1,0)=2 Then
								i=i-1
								While SendMessage(ah.hred,REM_ISLINEHIDDEN,i,0)And i>0
									i=SendMessage(ah.hred,REM_PRVBOOKMARK,i,2)
								Wend
								SendMessage(ah.hred,REM_EXPAND,i,0)
								SendMessage(ah.hred,REM_COLLAPSE,i,0)
							EndIf
							'
						Case IDM_FORMAT_LOCK
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							x=SendMessage(lpRESMEM->hResEd,DEM_ISLOCKED,0,0) Xor TRUE
							SendMessage(lpRESMEM->hResEd,DEM_LOCKCONTROLS,0,x)
							fTimer=1
							'
						Case IDM_FORMAT_BACK
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_SENDTOBACK,0,0)
							'
						Case IDM_FORMAT_FRONT
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_BRINGTOFRONT,0,0)
							'
						Case IDM_FORMAT_GRID
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							x=GetWindowLong(lpRESMEM->hResEd,GWL_STYLE) Xor DES_GRID
							SetWindowLong(lpRESMEM->hResEd,GWL_STYLE,x)
							fTimer=1
							'
						Case IDM_FORMAT_SNAP
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							x=GetWindowLong(lpRESMEM->hResEd,GWL_STYLE) Xor DES_SNAPTOGRID
							SetWindowLong(lpRESMEM->hResEd,GWL_STYLE,x)
							fTimer=1
							'
						Case IDM_FORMAT_ALIGN_LEFT
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,ALIGN_LEFT)
							'
						Case IDM_FORMAT_ALIGN_CENTER
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,ALIGN_CENTER)
							'
						Case IDM_FORMAT_ALIGN_RIGHT
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,ALIGN_RIGHT)
							'
						Case IDM_FORMAT_ALIGN_TOP
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,ALIGN_TOP)
							'
						Case IDM_FORMAT_ALIGN_MIDDLE
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,ALIGN_MIDDLE)
							'
						Case IDM_FORMAT_ALIGN_BOTTOM
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,ALIGN_BOTTOM)
							'
						Case IDM_FORMAT_SIZE_WIDTH
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,SIZE_WIDTH)
							'
						Case IDM_FORMAT_SIZE_HEIGHT
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,SIZE_HEIGHT)
							'
						Case IDM_FORMAT_SIZE_BOTH
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,SIZE_BOTH)
							'
						Case IDM_FORMAT_CENTER_HOR
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,ALIGN_DLGHCENTER)
							'
						Case IDM_FORMAT_CENTER_VER
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_ALIGNSIZE,0,ALIGN_DLGVCENTER)
							'
						Case IDM_FORMAT_TAB
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_SHOWTABINDEX,0,0)
							'
						Case IDM_FORMAT_RENUM
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_AUTOID,0,0)
							'
						Case IDM_FORMAT_CASECONVERT
							CaseConvert(ah.hred)
							'
						Case IDM_FORMAT_INDENT
							FormatIndent(ah.hred)
							'
						Case IDM_VIEW_OUTPUT
							wpos.fview=wpos.fview Xor VIEW_OUTPUT
							SendMessage(hWin,WM_SIZE,0,0)
							If wpos.fview And VIEW_OUTPUT Then
								ShowWindow(ah.hout,SW_SHOW)
								SendMessage(ah.htoolbar,TB_CHECKBUTTON,IDM_VIEW_OUTPUT,TRUE)
							Else
								ShowWindow(ah.hout,SW_HIDE)
								SendMessage(ah.htoolbar,TB_CHECKBUTTON,IDM_VIEW_OUTPUT,FALSE)
								If ah.hred Then
									SetFocus(ah.hred)
								EndIf
							EndIf
							fTimer=1
							'
						Case IDM_VIEW_PROJECT
							wpos.fview=wpos.fview Xor VIEW_PROJECT
							SendMessage(hWin,WM_SIZE,0,0)
							If wpos.fview And VIEW_PROJECT Then
								ShowWindow(ah.htab,SW_SHOWNA)
								ShowProjectTab
								SendMessage(ah.htoolbar,TB_CHECKBUTTON,IDM_VIEW_PROJECT,TRUE)
							Else
								ShowWindow(ah.htab,SW_HIDE)
								ShowWindow(ah.hfib,SW_HIDE)
								ShowWindow(ah.hprj,SW_HIDE)
								SendMessage(ah.htoolbar,TB_CHECKBUTTON,IDM_VIEW_PROJECT,FALSE)
							EndIf
							fTimer=1
							'
						Case IDM_VIEW_PROPERTY
							wpos.fview=wpos.fview Xor VIEW_PROPERTY
							SendMessage(hWin,WM_SIZE,0,0)
							If wpos.fview And VIEW_PROPERTY Then
								ShowWindow(ah.hpr,SW_SHOWNA)
								SendMessage(ah.htoolbar,TB_CHECKBUTTON,IDM_VIEW_PROPERTY,TRUE)
							Else
								ShowWindow(ah.hpr,SW_HIDE)
								SendMessage(ah.htoolbar,TB_CHECKBUTTON,IDM_VIEW_PROPERTY,FALSE)
							EndIf
							fTimer=1
							'
						Case IDM_VIEW_DIALOG
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hResEd,DEM_SHOWDIALOG,0,0)
							'
						Case IDM_VIEW_SPLITSCREEN
							x=SendMessage(ah.hred,REM_GETSPLIT,0,0)
							If x Then
								x=0
							Else
								x=500
							EndIf
							SendMessage(ah.hred,REM_SETSPLIT,x,0)
							'
						Case IDM_VIEW_FULLSCREEN
							If ah.hfullscreen Then
								DestroyWindow(ah.hfullscreen)
								SendMessage(hWin,WM_SIZE,0,0)
							Else
								 ah.hfullscreen=CreateWindowEx(NULL,@szFullScreenClassName,NULL,WS_POPUP Or WS_VISIBLE Or WS_MAXIMIZE,0,0,0,0,hWin,NULL,hInstance,NULL)
								SetFullScreen(ah.hred)
							EndIf
							'
						Case IDM_PROJECT_ADDNEWFILE
							AddNewProjectFile()
							'
						Case IDM_PROJECT_ADDNEWMODULE
							AddNewProjectModule
							'
						Case IDM_PROJECT_ADDEXISTINGFILE
							AddExistingProjectFile()
							'
						Case IDM_PROJECT_ADDEXISTINGMODULE
							AddExistingProjectModule
							'
						Case IDM_PROJECT_REMOVE
							RemoveProjectFile
							'
						Case IDM_PROJECT_RENAME
							SetFocus(ah.hprj)
							lret=SendMessage(ah.hprj,TVM_GETNEXTITEM,TVGN_CARET,0)
							If lret<>SendMessage(ah.hprj,TVM_GETNEXTITEM,TVGN_ROOT,0) Then
								SendMessage(ah.hprj,TVM_EDITLABEL,0,lret)
							EndIf
							'
						Case IDM_PROJECT_OPTIONS
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGPROJECTOPTION),hWin,@ProjectOptionDlgProc,NULL)
							'
						Case IDM_PROJECT_CREATETEMPLATE
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_CREATETEMPLATE),hWin,@CreateTemplateDlgProc,NULL)
							'
						Case IDM_RESOURCE_DIALOG
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_ADDITEM,TPE_DIALOG,TRUE)
							'
						Case IDM_RESOURCE_MENU
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_ADDITEM,TPE_MENU,TRUE)
							'
						Case IDM_RESOURCE_ACCEL
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_ADDITEM,TPE_ACCEL,TRUE)
							'
						Case IDM_RESOURCE_STRINGTABLE
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_ADDITEM,TPE_STRING,TRUE)
							'
						Case IDM_RESOURCE_VERSION
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_ADDITEM,TPE_VERSION,TRUE)
							'
						Case IDM_RESOURCE_XPMANIFEST
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_ADDITEM,TPE_XPMANIFEST,TRUE)
							'
						Case IDM_RESOURCE_RCDATA
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_ADDITEM,TPE_RCDATA,TRUE)
							'
						Case IDM_RESOURCE_LANGUAGE
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_ADDITEM,TPE_LANGUAGE,TRUE)
							'
						Case IDM_RESOURCE_INCLUDE
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_ADDITEM,TPE_INCLUDE,TRUE)
							'
						Case IDM_RESOURCE_RES
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_ADDITEM,TPE_RESOURCE,TRUE)
							'
						Case IDM_RESOURCE_NAMES
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_SHOWNAMES,0,Cast(Integer,ah.hout))
							'
						Case IDM_RESOURCE_EXPORT
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_EXPORTNAMES,0,Cast(Integer,ah.hout))
							'
						Case IDM_RESOURCE_REMOVE
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_DELITEM,0,0)
							'
						Case IDM_RESOURCE_UNDO
							lpRESMEM=Cast(RESMEM ptr,GetWindowLong(ah.hred,0))
							SendMessage(lpRESMEM->hProject,PRO_UNDODELETED,0,0)
							'
						Case IDM_MAKE_COMPILE
							fQR=FALSE
							Compile(ad.smake)
							'
						Case IDM_MAKE_GO
							fQR=FALSE
							If Compile(ad.smake)=0 Then
								If fProject Then
									sFile=GetProjectFile(1)
								Else
									sFile=ad.filename
								EndIf
								If Len(ad.smakeoutput) Then
									sFile=ad.ProjectPath & "\" & ad.smakeoutput
								EndIf
								MakeRun(sFile,FALSE)
							EndIf
							'
						Case IDM_MAKE_RUN
							fQR=FALSE
							If fProject Then
								sFile=GetProjectFileName(1)
							Else
								sFile=ad.filename
							EndIf
							If Len(ad.smakeoutput) Then
								sFile=ad.ProjectPath & "\" & ad.smakeoutput
							EndIf
							MakeRun(sFile,FALSE)
							'
						Case IDM_MAKE_RUNDEBUG
							fQR=FALSE
							If fProject Then
								sFile=GetProjectFileName(1)
							Else
								sFile=ad.filename
							EndIf
							If Len(ad.smakeoutput) Then
								MakeRun(ad.smakeoutput,TRUE)
							Else
								MakeRun(sFile,TRUE)
							EndIf
							'
						Case IDM_MAKE_MODULE
							fQR=FALSE
							CompileModules(ad.smakemodule)
							'
						Case IDM_MAKE_QUICKRUN
							bm=wpos.fview And VIEW_OUTPUT
							' Clear errors
							UpdateAllTabs(2)
							If ad.filename="(Untitled).bas" Then
								sItem=ad.AppPath
							Else
								sItem=ad.filename
								GetFilePath(sItem)
							EndIf
							SetCurrentDirectory(sItem)
							sItem="FbTemp.bas"
							SaveTempFile(ah.hred,sItem)
							fBuildErr=Make(ad.smake,sItem,FALSE,FALSE,TRUE)
							DeleteFile(StrPtr("FbTemp.bas"))
							If fBuildErr=0 Then
								If bm=0 Then
									nHideOut=15
								EndIf
								CreateThread(NULL,NULL,Cast(Any ptr,@MakeThreadProc),Cast(ZString ptr,@"FbTemp.exe"),NORMAL_PRIORITY_CLASS,@x)
							Else
								fQR=TRUE
								nHideOut=0
							EndIf
							'
						Case IDM_TOOLS_EXPORT
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGEXPORT),hWin,@ExportDlgProc,0)
							'
						Case IDM_OPTIONS_CODE
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGKEYWORDS),hWin,@KeyWordsDlgProc,0)
							'
						Case IDM_OPTIONS_DIALOG
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_TABOPTIONS),hWin,@TabOptionsProc,0)
							'
						Case IDM_OPTIONS_PATH
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGPATHOPTION),hWin,@PathOptDlgProc,0)
							'
						Case IDM_OPTIONS_DEBUG
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGDEBUGOPT),hWin,@DebugOptDlgProc,0)
							'
						Case IDM_OPTIONS_MAKE
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGOPTMNU),hWin,@MenuOptionDlgProc,3)
							'
						Case IDM_OPTIONS_EXTERNALFILES
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGEXTERNALFILE),hWin,@ExternalFileDlgProc,0)
							'
						Case IDM_OPTIONS_ADDINS
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGADDINMANAGER),hWin,@AddinManagerProc,0)
							'
						Case IDM_OPTIONS_TOOLS
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGOPTMNU),hWin,@MenuOptionDlgProc,1)
							'
						Case IDM_OPTIONS_HELP
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGOPTMNU),hWin,@MenuOptionDlgProc,2)
							'
						Case IDM_HELP_ABOUT
							DialogBoxParam(hInstance,Cast(ZString ptr,IDD_DLGABOUT),hWin,@AboutDlgProc,0)
							SetFocus(ah.hred)
							'
						Case IDM_HELPF1
							GetPrivateProfileString(StrPtr("Help"),Str(1),@szNULL,@buff,260,@ad.IniFile)
							If Len(buff) Then
								buff=Mid(buff,InStr(buff,",")+1)
								If Asc(buff)=Asc("\") Then
									buff=Left(ad.AppPath,2) & buff
								EndIf
								SendMessage(ah.hred,REM_GETWORD,SizeOf(s),Cast(Integer,@s))
								x=FileType(buff)
								If x=3 Then
									WinHelp(hWin,@buff,HELP_KEY,Cast(Integer,@s))
								ElseIf x=4 Then
									HH_Help()
								Else
									ShellExecute(hWin,NULL,@buff,NULL,@s,SW_SHOWNORMAL)
								EndIf
							EndIf
							'
						Case IDM_HELPCTRLF1
							GetPrivateProfileString(StrPtr("Help"),Str(2),@szNULL,@buff,256,@ad.IniFile)
							If Len(buff) Then
								buff=Mid(buff,InStr(buff,",")+1)
								If Asc(buff)=Asc("\") Then
									buff=Left(ad.AppPath,2) & buff
								EndIf
								SendMessage(ah.hred,REM_GETWORD,SizeOf(s),Cast(Integer,@s))
								x=FileType(buff)
								If x=3 Then
									WinHelp(hWin,@buff,HELP_KEY,Cast(Integer,@s))
								ElseIf x=4 Then
									HH_Help()
								Else
									ShellExecute(hWin,NULL,@buff,NULL,@s,SW_SHOWNORMAL)
								EndIf
							EndIf
							'
						Case &HFFFD
							' Expand button clicked
							SendMessage(ah.hred,REM_EXPANDALL,0,0)
							SendMessage(ah.hred,EM_SCROLLCARET,0,0)
							SendMessage(ah.hred,REM_REPAINT,0,0)
							'
						Case &HFFFC
							' Collapse button clicked
							SendMessage(ah.hred,REM_COLLAPSEALL,0,0)
							SendMessage(ah.hred,EM_SCROLLCARET,0,0)
							SendMessage(ah.hred,REM_REPAINT,0,0)
							'
						Case IDM_NEXTTAB
							NextTab(FALSE)
							'
						Case IDM_PREVIOUSTAB
							NextTab(TRUE)
							'
						Case IDM_SWITCHTAB
							SwitchTab()
							'
						Case IDM_OUTPUT_CLEAR
							SendMessage(ah.hout,WM_SETTEXT,0,Cast(Integer,StrPtr(szNULL)))
							nLinesOut=0
							UpdateAllTabs(6)
							'
						Case IDM_OUTPUT_SELECTALL
							chrg.cpMin=0
							chrg.cpMax=-1
							SendMessage(ah.hout,EM_EXSETSEL,0,Cast(Integer,@chrg))
							'
						Case IDM_OUTPUT_COPY
							SendMessage(ah.hout,WM_COPY,0,0)
							'
						Case IDM_PROPERTY_JUMP
							SendMessage(ah.hpr,WM_COMMAND,(LBN_DBLCLK Shl 16) Or 1003,0)
							'
						Case IDM_PROPERTY_COPY
							If SendMessage(ah.hpr,PRM_GETSELTEXT,0,Cast(LPARAM,@buff)) Then
								If InStr(buff,"(") Then
									buff=Left(buff,InStr(buff,"(")-1)
								ElseIf InStr(buff,":") Then
									buff=Left(buff,InStr(buff,":")-1)
								EndIf
								SendMessage(ah.hred,EM_REPLACESEL,TRUE,Cast(LPARAM,@buff))
								SetFocus(ah.hred)
							EndIf
							'
						Case IDM_WINDOW_SPLITT
							If ah.hred<>ah.hres Then
								If SendMessage(ah.hred,REM_GETSPLIT,0,0) Then
									SendMessage(ah.hred,REM_SETSPLIT,0,0)
								Else
									SendMessage(ah.hred,REM_SETSPLIT,500,0)
								EndIf
							EndIf
							'
						Case IDM_WINDOW_ALL_BUT_CURRENT
							If ah.hred Then
								If CloseAllTabs(hWin,FALSE,ah.hred)=FALSE Then
									'
								EndIf
								If SendMessage(ah.hpr,PRM_GETSELBUTTON,0,0)=1 Then
									UpdateFileProperty
								EndIf
								fTimer=1
							EndIf
							'
						Case IDC_CBOBUILD
							id=SendMessage(ah.hcbobuild,CB_GETCURSEL,0,0)
							If fProject Then
								WritePrivateProfileString(StrPtr("Make"),StrPtr("Current"),Str(id+1),@ad.ProjectFile)
							Else
								WritePrivateProfileString(StrPtr("Make"),StrPtr("Current"),Str(id+1),@ad.IniFile)
							EndIf
							GetMakeOption
							'
						Case Else
							If id>=11000 And id<=11019 Then
								' Tools menu
								GetPrivateProfileString(StrPtr("Tools"),Str(id-10999),@szNULL,@buff,260,@ad.IniFile)
								If Len(buff) Then
									buff=Mid(buff,InStr(buff,",")+1)
									If Asc(buff)=Asc("\") Then
										buff=Left(ad.AppPath,2) & buff
									EndIf
									If InStr(buff," $" & szNULL) Then
										buff[Len(buff)-2]=NULL
										ShellExecute(hWin,NULL,@buff,@ad.filename,NULL,SW_SHOWNORMAL)
									ElseIf Asc(buff)=Asc("$") Then
										GetCurrentDirectory(260,@buff)
										lstrcat(@buff,StrPtr("\"))
										ShellExecute(hWin,StrPtr("explore"),@buff,NULL,NULL,SW_SHOWNORMAL)
									Else
										ShellExecute(hWin,NULL,@buff,NULL,NULL,SW_SHOWNORMAL)
									EndIf
								EndIf
							ElseIf id>=12000 And id<=12019 Then
								' Help menu
								GetPrivateProfileString(StrPtr("Help"),Str(id-11999),@szNULL,@buff,256,@ad.IniFile)
								If Len(buff) Then
									buff=Mid(buff,InStr(buff,",")+1)
									If Asc(buff)=Asc("\") Then
										buff=Left(ad.AppPath,2) & buff
									EndIf
									ShellExecute(hWin,NULL,@buff,NULL,NULL,SW_SHOWNORMAL)
								EndIf
							ElseIf id>=14001 And id<=14004 Then
								' Mru project
								x=InStr(MruProject(id-14001),",")
								If x Then
									If fProject Then
										If CloseProject=FALSE Then
											Return TRUE
										EndIf
									Else
										If CloseAllTabs(hWin,FALSE,0)=TRUE Then
											Return TRUE
										EndIf
									EndIf
									ad.ProjectFile=Mid(MruProject(id-14001),x+1)
									OpenProject
								EndIf
							ElseIf id>=15001 And id<=15009 Then
								' Mru file
								x=InStr(MruFile(id-15001),",")
								If x Then
									OpenTheFile(Mid(MruFile(id-15001),x+1))
								EndIf
							EndIf
							'
					End Select
					'
			End Select
			'
		Case WM_CONTEXTMENU
			If lParam=-1 Then
				hCtl=GetFocus
				GetCaretPos(@pt)
				ClientToScreen(hCtl,@pt)
				pt.x=pt.x+10
			Else
				pt.x=lParam And &HFFFF
				pt.y=lParam Shr 16
				hCtl=WindowFromPoint(pt)
			EndIf
			hCtl=Cast(HWND,wParam)
			If hCtl=ah.hprj Then
				' Project
				hMnu=GetSubMenu(ah.hcontextmenu,1)
				TrackPopupMenu(hMnu,TPM_LEFTALIGN Or TPM_RIGHTBUTTON,pt.x,pt.y,0,ah.hwnd,0)
			ElseIf hCtl=ah.hpr Then
				' Property
				hMnu=GetSubMenu(ah.hcontextmenu,3)
				TrackPopupMenu(hMnu,TPM_LEFTALIGN Or TPM_RIGHTBUTTON,pt.x,pt.y,0,ah.hwnd,0)
			ElseIf hCtl=hWin Then
				' Main window
				hMnu=GetSubMenu(GetMenu(ah.hwnd),0)
				TrackPopupMenu(hMnu,TPM_LEFTALIGN Or TPM_RIGHTBUTTON,pt.x,pt.y,0,ah.hwnd,0)
			ElseIf hCtl=ah.htabtool Then
				' Tab select
				hMnu=GetSubMenu(ah.hcontextmenu,0)
				TrackPopupMenu(hMnu,TPM_LEFTALIGN Or TPM_RIGHTBUTTON,pt.x,pt.y,0,ah.hwnd,0)
			EndIf
		Case WM_MOVE
			ShowWindow(ah.htt,SW_HIDE)
			HideList()
			'
		Case WM_NOTIFY
			lpRASELCHANGE=Cast(RASELCHANGE ptr,lParam)
			If lpRASELCHANGE->nmhdr.hwndFrom=ah.hred Then
				If lpRASELCHANGE->seltyp=SEL_OBJECT Then
					bm=SendMessage(ah.hred,REM_GETBOOKMARK,lpRASELCHANGE->Line,0)
					If bm=1 Then
						' Collapse
						SendMessage(ah.hred,REM_COLLAPSE,lpRASELCHANGE->Line,0)
					ElseIf bm=2 Then
						' Expand
						SendMessage(ah.hred,REM_EXPAND,lpRASELCHANGE->Line,0)
					EndIf
				Else
					If GetWindowLong(ah.hred,GWL_ID)=IDC_CODEED Then
						SendMessage(ah.hred,REM_BRACKETMATCH,0,0)
						SendMessage(ah.hred,REM_SETHILITELINE,nLastLine,0)
						If edtopt.hiliteline Then
							SendMessage(ah.hred,REM_SETHILITELINE,lpRASELCHANGE->Line,2)
						EndIf
						If lpRASELCHANGE->Line<>nLastLine Then
							ShowWindow(ah.htt,SW_HIDE)
							HideList()
							If GetWindowLong(ah.hred,GWL_USERDATA)=1 Then
								' Must be parsed
								SetWindowLong(ah.hred,GWL_USERDATA,2)
							EndIf
						EndIf
						If lpRASELCHANGE->fchanged Then
							If lpRASELCHANGE->Line>=nLastLine And nLastLine>0 Then
								nLastLine=nLastLine-1
							ElseIf lpRASELCHANGE->Line<nLastLine Then
								nLastLine=nLastLine+1
							EndIf
							If GetWindowLong(ah.hred,GWL_USERDATA)=0 Then
								SetWindowLong(ah.hred,GWL_USERDATA,1)
							EndIf
							' Set comment block definition
							SendMessage(ah.hred,REM_SETCOMMENTBLOCKS,Cast(Integer,StrPtr("/'")),Cast(Integer,StrPtr("'/")))
							Do
								bm=SendMessage(ah.hred,REM_GETBOOKMARK,nLastLine,0)
								i=-1
								lret=-1
								While lret=-1 And i<31
									i=i+1
									If BD(i).lpszStart Then
										lret=SendMessage(ah.hred,REM_ISLINE,nLastLine,Cast(Integer,@szSt(i)))
									EndIf
								Wend
								If bm=1 Or bm=2 Then
									If lret=-1 Then
										' Remove collapse bookmark
										If bm=2 Then
											SendMessage(ah.hred,REM_EXPAND,nLastLine,0)
										EndIf
										SendMessage(ah.hred,REM_SETBOOKMARK,nLastLine,0)
										SendMessage(ah.hred,REM_SETDIVIDERLINE,nLastLine,FALSE)
										SendMessage(ah.hred,REM_SETSEGMENTBLOCK,nLastLine,FALSE)
									EndIf
								ElseIf bm=0 Then
									If lret<>-1 Then
										' Set collapse bookmark
										SendMessage(ah.hred,REM_SETBOOKMARK,nLastLine,1)
										SendMessage(ah.hred,REM_SETDIVIDERLINE,nLastLine,BD(i).flag And BD_DIVIDERLINE)
									EndIf
								EndIf
								bm=0
								If lpRASELCHANGE->Line>nLastLine Then
									nLastLine=nLastLine+1
									bm=1
								ElseIf lpRASELCHANGE->Line<nLastLine Then
									nLastLine=nLastLine-1
									bm=1
								EndIf
							Loop While bm
						EndIf
					EndIf
				EndIf
				nLastLine=lpRASELCHANGE->Line
				fTimer=1
			ElseIf lpRASELCHANGE->nmhdr.hwndFrom=ah.hout Then
				If lpRASELCHANGE->seltyp=SEL_OBJECT Then
					bm=SendMessage(ah.hout,REM_GETBOOKMARK,lpRASELCHANGE->Line,0)
					If bm=3 Then
						x=lpRASELCHANGE->Line
						While bm=3
							x-=1
							bm=SendMessage(ah.hout,REM_GETBOOKMARK,x,0)
						Wend
						buff=Chr(255) & Chr(1)
						x=SendMessage(ah.hout,EM_GETLINE,x,Cast(LPARAM,@buff))
						buff[x]=NULL
						OpenTheFile(buff)
						x=SendMessage(ah.hout,REM_GETBMID,lpRASELCHANGE->Line,0)
						If x Then
							x=SendMessage(ah.hred,REM_FINDBOOKMARK,x,0)
							If x>=0 Then
								y=x
							EndIf
						EndIf
						chrg.cpMin=SendMessage(ah.hred,EM_LINEINDEX,y,0)
						chrg.cpMax=chrg.cpMin
						SendMessage(ah.hred,EM_EXSETSEL,0,Cast(Integer,@chrg))
						SendMessage(ah.hred,REM_VCENTER,0,0)
						SendMessage(ah.hred,EM_SCROLLCARET,0,0)
						SetFocus(ah.hred)
					Else
						SendMessage(ah.hout,EM_EXGETSEL,0,Cast(LPARAM,@chrg))
						y=SendMessage(ah.hout,EM_LINEFROMCHAR,chrg.cpMin,0)
						x=SendMessage(ah.hout,EM_LINELENGTH,y,0)
						buff=Chr(x And 255) & Chr(x\256)
						x=SendMessage(ah.hout,EM_GETLINE,y,Cast(LPARAM,@buff))
						buff[x]=NULL
						y=GetErrLine(buff,fQR)
						If y>=0 Then
							If ah.hred<>ah.hres Then
								x=SendMessage(ah.hout,REM_GETBMID,lpRASELCHANGE->Line,0)
								If x Then
									x=SendMessage(ah.hred,REM_FINDBOOKMARK,x,0)
									If x>=0 Then
										y=x
									EndIf
								EndIf
								chrg.cpMin=SendMessage(ah.hred,EM_LINEINDEX,y,0)
								chrg.cpMax=chrg.cpMin
								SendMessage(ah.hred,EM_EXSETSEL,0,Cast(Integer,@chrg))
								SendMessage(ah.hred,REM_VCENTER,0,0)
								SendMessage(ah.hred,EM_SCROLLCARET,0,0)
							EndIf
							SetFocus(ah.hred)
						EndIf
					EndIf
				EndIf
				'
			ElseIf lpRASELCHANGE->nmhdr.code=TTN_NEEDTEXTA Then
				' ToolBar tooltip
				lpTOOLTIPTEXT=Cast(TOOLTIPTEXT ptr,lParam)
				lret=CallAddins(ah.hwnd,AIM_GETTOOLTIP,lpTOOLTIPTEXT->hdr.idFrom,0,HOOK_GETTOOLTIP)
				If lret Then
					lpTOOLTIPTEXT->lpszText=Cast(ZString ptr,lret)
				Else
					LoadString(hInstance,lpTOOLTIPTEXT->hdr.idFrom,@buff,256)
					lpTOOLTIPTEXT->lpszText=@buff
				EndIf
			ElseIf lpRASELCHANGE->nmhdr.code=TCN_SELCHANGE And lpRASELCHANGE->nmhdr.idFrom=IDC_TABSELECT Then
				' Tab select
				hCtl=ah.hred
				tci.mask=TCIF_PARAM
				SendMessage(lpRASELCHANGE->nmhdr.hwndFrom,TCM_GETITEM,SendMessage(lpRASELCHANGE->nmhdr.hwndFrom,TCM_GETCURSEL,0,0),Cast(Integer,@tci))
				lpTABMEM=Cast(TABMEM ptr,tci.lParam)
				ah.hred=lpTABMEM->hedit
				ad.filename=lpTABMEM->filename
				SendMessage(hWin,WM_SIZE,0,0)
				ShowWindow(ah.hred,SW_SHOW)
				ShowWindow(hCtl,SW_HIDE)
				SetFocus(ah.hred)
				SetWinCaption
				If SendMessage(ah.hpr,PRM_GETSELBUTTON,0,0)=1 Then
					UpdateFileProperty
				EndIf
				ShowWindow(ah.htt,SW_HIDE)
				HideList()
				fTimer=1
			ElseIf lpRASELCHANGE->nmhdr.code=TCN_SELCHANGE And lpRASELCHANGE->nmhdr.idFrom=IDC_TAB Then
				' Project tab
				ShowProjectTab
			ElseIf lpRASELCHANGE->nmhdr.code=FBN_DBLCLICK  And lpRASELCHANGE->nmhdr.idFrom=IDC_FILEBROWSER Then
				' File dblclicked
				lpFBNOTIFY=Cast(FBNOTIFY ptr,lParam)
				lstrcpy(@sItem,lpFBNOTIFY->lpfile)
				OpenTheFile(sItem)
				If SendMessage(ah.hpr,PRM_GETSELBUTTON,0,0)=1 Then
					UpdateFileProperty
				EndIf
			ElseIf lpRASELCHANGE->nmhdr.code=BN_CLICKED And lpRASELCHANGE->nmhdr.idFrom=IDC_PROPERTY Then
				lpRAPNOTIFY=Cast(RAPNOTIFY ptr,lParam)
				Select Case lpRAPNOTIFY->nid
					Case 1
						UpdateFileProperty
					Case 2
						SendMessage(ah.hpr,PRM_SELOWNER,0,0)
					Case 5
						SendMessage(ah.hpr,PRM_REFRESHLIST,0,0)
				End Select
			ElseIf lpRASELCHANGE->nmhdr.code=LBN_DBLCLK And lpRASELCHANGE->nmhdr.idFrom=IDC_PROPERTY Then
				lpRAPNOTIFY=Cast(RAPNOTIFY ptr,lParam)
				If fProject Then
					SelectTab(hWin,0,lpRAPNOTIFY->nid)
				Else
					SelectTab(hWin,Cast(HWND,lpRAPNOTIFY->nid),0)
				EndIf
				chrg.cpMin=SendMessage(ah.hred,EM_LINEINDEX,lpRAPNOTIFY->nline,0)
				chrg.cpMax=chrg.cpMin
				SendMessage(ah.hred,EM_EXSETSEL,0,Cast(Integer,@chrg))
				SendMessage(ah.hred,REM_VCENTER,0,0)
				SetFocus(ah.hred)
			ElseIf lpRASELCHANGE->nmhdr.code=LBN_SELCHANGE And lpRASELCHANGE->nmhdr.idFrom=IDC_PROPERTY Then
				fTimer=1
			ElseIf lpRASELCHANGE->nmhdr.code=TVN_BEGINLABELEDIT Then
				lpNMTVDISPINFO=Cast(NMTVDISPINFO ptr,lParam)
				lstrcpy(@sEditFileName,lpNMTVDISPINFO->item.pszText)
				If lpNMTVDISPINFO->item.lParam=0 Then
					SendMessage(ah.hprj,TVM_ENDEDITLABELNOW,0,0)
				EndIf
			ElseIf lpRASELCHANGE->nmhdr.code=TVN_ENDLABELEDIT Then
				lpNMTVDISPINFO=Cast(NMTVDISPINFO ptr,lParam)
				lstrcpy(@sItem,lpNMTVDISPINFO->item.pszText)
				SetCurrentDirectory(@ad.ProjectPath)
				If MoveFile(@sEditFileName,@sItem) Then
					SendMessage(ah.hprj,TVM_SETITEM,0,Cast(Integer,@lpNMTVDISPINFO->item))
					UpdateProjectFileName(sEditFileName,sItem)
					sEditFileName=MakeProjectFileName(sEditFileName)
					If IsFileOpen(hWin,sEditFileName,TRUE) Then
						ad.filename=MakeProjectFileName(sItem)
						UpdateTab
						SetWinCaption
					EndIf
					RefreshProjectTree
				EndIf
			EndIf
			'
		Case WM_DROPFILES
			id=0
			lret=TRUE
			Do While lret
				lret=DragQueryFile(Cast(HDROP,wParam),id,@sItem,SizeOf(sItem))
				If lret Then
					' Open single file
					OpenTheFile(sItem)
				EndIf
				id=id+1
			Loop
			'
		Case WM_SIZE
			If ah.hfullscreen=0 Then
				' Size the FbEdit control to fill the dialogs client area
				twt=wpos.wtpro
				If (wpos.fview And (VIEW_PROJECT Or VIEW_PROPERTY))=0 Then
					twt=0
				EndIf
				' Get dialogs client rect
				GetClientRect(hWin,@rect)
				' Size the divider
				hCtl=GetDlgItem(hWin,IDC_DIVIDER2)
				MoveWindow(hCtl,0,0,rect.right+1,2,TRUE)
				' Get height of toolbar
				GetClientRect(ah.htoolbar,@rect1)
				hgt=rect1.bottom+3
				If rect1.right<>ad.tbwt Then
					rect1.right=ad.tbwt
					MoveWindow(ah.htoolbar,0,3,rect1.right,rect1.bottom,TRUE)
					MoveWindow(ah.hcbobuild,ad.tbwt,3,150,200,TRUE)
					MoveWindow(ah.hfindinpage,ad.tbwt+152,3,100,21,TRUE)
				EndIf
				' Size the divider
				hCtl=GetDlgItem(hWin,IDC_DIVIDER)
				MoveWindow(hCtl,0,hgt,rect.right+1,2,TRUE)
				' Add height of divider
				hgt=hgt+4
				tbhgt=hgt
				' Size the tab select
				GetClientRect(ah.htabtool,@rect1)
				MoveWindow(ah.htabtool,0,hgt,rect.right-twt-17,rect1.bottom,TRUE)
				' Size close button
				hCtl=GetDlgItem(hWin,IDM_FILE_CLOSE)
				MoveWindow(hCtl,rect.right-twt-15,hgt+4,15,15,TRUE)
				' Add height of tab select
				hgt=hgt+rect1.bottom'+1
				' Autosize the statusbar
				MoveWindow(ah.hsbr,0,0,0,0,TRUE)
				' Get client rect of statusbar
				GetClientRect(ah.hsbr,@rect1)
				prjht=0
				prht=0
				If (wpos.fview And (VIEW_PROJECT Or VIEW_PROPERTY))=(VIEW_PROJECT Or VIEW_PROPERTY) Then
					prjht=(rect.bottom-tbhgt-rect1.bottom)/2
					prht=rect.bottom-tbhgt-rect1.bottom-prjht
				ElseIf (wpos.fview And (VIEW_PROJECT Or VIEW_PROPERTY))=VIEW_PROJECT Then
					prjht=(rect.bottom-tbhgt-rect1.bottom)
				ElseIf (wpos.fview And (VIEW_PROJECT Or VIEW_PROPERTY))=VIEW_PROPERTY Then
					prht=(rect.bottom-tbhgt-rect1.bottom)
				EndIf
				' Size the tab
				MoveWindow(ah.htab,rect.right-twt+2,tbhgt,twt-2,prjht,TRUE)
				' Size the file browser
				MoveWindow(ah.hfib,rect.right-twt+3,tbhgt+22,twt-5,prjht-24,TRUE)
				' Size the project browser
				MoveWindow(ah.hprj,rect.right-twt+3,tbhgt+22,twt-5,prjht-24,TRUE)
				' Size the property
				MoveWindow(ah.hpr,rect.right-twt+2,tbhgt+prjht,twt-2,prht,TRUE)
				' Size the shape
				MoveWindow(ah.hshp,0,hgt,rect.right-twt,rect.bottom-hgt-rect1.bottom-wpos.htout*(wpos.fview And VIEW_OUTPUT),TRUE)
				' Size the edit control
				MoveWindow(ah.hred,0,hgt,rect.right-twt,rect.bottom-hgt-rect1.bottom-wpos.htout*(wpos.fview And VIEW_OUTPUT),TRUE)
				' Size the Output
				MoveWindow(ah.hout,0,rect.bottom-rect1.bottom-wpos.htout+2,rect.right-twt,wpos.htout-2,TRUE)
				' Size the splash
				GetWindowRect(ah.hshp,@rect1)
				ScreenToClient(hWin,Cast(POINT ptr,@rect1.right))
				MoveWindow(GetDlgItem(hWin,IDC_IMGSPLASH),(rect1.right-340)/2,(rect1.bottom-188)/2+25,340,188,TRUE)
			EndIf
			'
		Case WM_MOUSEMOVE,WM_LBUTTONDOWN,WM_LBUTTONUP
			' Size tool windows
			x=LoWord(lParam)
			If x>&H7FFF Then
				x=&HFFFF0000 Or x
			EndIf
			y=HiWord(lParam)
			If y>&H7FFF Then
				y=&HFFFF0000 Or y
			EndIf
			GetWindowRect(ah.hshp,@rect)
			ScreenToClient(hWin,Cast(Point ptr,@rect.right))
			If x>=rect.right And x<rect.right+3 Then
				SetCursor(hVCur)
				If uMsg=WM_LBUTTONDOWN Then
					SetCapture(hWin)
					nSize=1
				ElseIf uMsg=WM_LBUTTONUP Then
					If GetCapture=hWin Then
						ReleaseCapture
						nSize=0
					EndIf
				EndIf
			ElseIf y>=rect.bottom And y<rect.bottom+3 Then
				SetCursor(hHCur)
				If uMsg=WM_LBUTTONDOWN Then
					SetCapture(hWin)
					nSize=2
				ElseIf uMsg=WM_LBUTTONUP Then
					If GetCapture=hWin Then
						ReleaseCapture
						nSize=0
					EndIf
				EndIf
			Else
				If GetCapture=hWin Then
					If uMsg=WM_LBUTTONUP Then
						ReleaseCapture
						nSize=0
					EndIf
				Else
					SetCursor(LoadCursor(0,IDC_ARROW))
				EndIf
			EndIf
			If uMsg=WM_MOUSEMOVE Then
				If nSize=1 Then
					GetClientRect(hWin,@rect)
					x=rect.right-x
					If x<100 Then
						x=100
					ElseIf x>rect.right-100 Then
						x=rect.right-100
					EndIf
					If x<>wpos.wtpro Then
						wpos.wtpro=x
						SendMessage(hWin,WM_SIZE,0,0)
						UpdateWindow(hWin)
					EndIf
				ElseIf nSize=2 Then
					GetClientRect(hWin,@rect)
					GetClientRect(ah.hsbr,@rect1)
					y=rect.bottom-rect1.bottom-y
					If y<50 Then
						y=50
					ElseIf y>rect.bottom-150 Then
						y=rect.bottom-150
					EndIf
					If y<>wpos.htout Then
						wpos.htout=y
						SendMessage(hWin,WM_SIZE,0,0)
						UpdateWindow(hWin)
					EndIf
				EndIf
			EndIf
			'
			Return DefWindowProc(hWin,uMsg,wParam,lParam)
		Case WM_SETFOCUS
			If ah.hred Then
				' Hack to solve a caret problem
				SetFocus(ah.hred)
				SetFocus(ah.hout)
				SetFocus(ah.hred)
			EndIf
			'
		Case AIM_GETHANDLES
			Return Cast(Integer,@ah)
			'
		Case AIM_GETDATA
			Return Cast(Integer,@ad)
			'
		Case AIM_GETFUNCTIONS
			Return Cast(Integer,@af)
			'
		Case AIM_GETMENUID
			mnuid=mnuid+1
			Return mnuid
			'
		Case WM_COPYDATA
			lpCOPYDATASTRUCT=Cast(COPYDATASTRUCT ptr,lParam)
			CommandLine=lpCOPYDATASTRUCT->lpData
			CmdLine
			'
		Case WM_QUERYENDSESSION
			SendMessage(hWin,WM_CLOSE,0,0)
			'
		Case Else
			Return DefWindowProc(hWin,uMsg,wParam,lParam)
			'
	End Select
	Return 0

End Function

Function WinMain(ByVal hInst As HINSTANCE,ByVal hPrevInst As HINSTANCE,ByVal lpCmdLine As LPSTR,ByVal CmdShow As Integer) As Integer
	Dim wcex As WNDCLASSEXA
	Dim msg As MSG
	Dim cpd As COPYDATASTRUCT

	' Get AppPath
	GetModuleFileName(NULL,@ad.AppPath,260)
	GetFilePath(ad.AppPath)
	' Get inifilename
	GetModuleFileName(NULL,@ad.IniFile,260)
	Mid(ad.IniFile,Len(ad.IniFile)-2,3)="ini"
	GetPrivateProfileString(StrPtr("Win"),StrPtr("AppPath"),@szNULL,@buff,260,@ad.IniFile)
	If Len(buff) Then
		' FbEdit development, use main ini file
		ad.AppPath=buff
		ad.IniFile=buff & "\FbEdit.ini"
	EndIf
	SetCurrentDirectory(@ad.AppPath)
	LoadFromIni(StrPtr("Win"),StrPtr("Winpos"),"4444444444444444444",@wpos,FALSE)
	' Get command line filename
	CommandLine=GetCommandLine
	CommandLine=PathGetArgs(CommandLine)
	If wpos.singleinstance Then
		ah.hwnd=FindWindow(StrPtr("MAINFBEDIT"),NULL)
		If ah.hwnd Then
			If IsIconic(ah.hwnd) Then
				ShowWindow(ah.hwnd,SW_RESTORE)
			EndIf
			' Get command line filename
			If Len(CommandLine[0]) Then
				cpd.dwData=0
				cpd.lpData=CommandLine
				cpd.cbData=Len(CommandLine[0])+1
				SendMessage(ah.hwnd,WM_COPYDATA,0,Cast(LPARAM,@cpd))
			EndIf
			Return 0
		EndIf
	EndIf
	wcex.cbSize=SizeOf(WNDCLASSEX)
	wcex.style=CS_HREDRAW Or CS_VREDRAW
	wcex.lpfnWndProc=@DlgProc
	wcex.cbClsExtra=NULL
	wcex.cbWndExtra=DLGWINDOWEXTRA
	wcex.hInstance=hInst
	wcex.hbrBackground=Cast(HBRUSH,COLOR_BTNFACE+1)
	wcex.lpszMenuName=Cast(ZString ptr,10000)
	wcex.lpszClassName=StrPtr("MAINFBEDIT")
	hIcon=LoadIcon(hInstance,Cast(ZString ptr,IDC_MAINICON))
	wcex.hIcon=hIcon
	wcex.hIconSm=0
	wcex.hCursor=LoadCursor(NULL,IDC_ARROW)
	RegisterClassEx(@wcex)
	CreateDialogParam(hInst,Cast(ZString ptr,IDD_MAIN),NULL,@DlgProc,NULL)
	If wpos.fMax Then
		ShowWindow(ah.hwnd,SW_MAXIMIZE)
		''' i suggest change next line to sendmessage because
		''' postmessage interferes/asynchronizes in the load of addins and 
		''' first refresh/update of main window can fails.
		SendMessage(ah.hwnd,WM_SIZE,0,0)
		'PostMessage(ah.hwnd,WM_SIZE,0,0)
	Else
		ShowWindow(ah.hwnd,SW_SHOWNORMAL)
	EndIf
	UpdateWindow(ah.hwnd)
	CmdLine
	Do While GetMessage(@msg,NULL,0,0)
		If TranslateAccelerator(ah.hwnd,ah.haccel,@msg)=0 Then
			If IsDialogMessage(ah.hfind,@msg)=0 Then
				TranslateMessage(@msg)
				DispatchMessage(@msg)
			EndIf
		EndIf
	Loop
	Return msg.wParam

End Function

Dim CharTab As Function() As Any ptr

'{	Program start

	''
	'' Create the Dialog
	''
	hInstance=GetModuleHandle(NULL)
	hRichEditDll=LoadLibrary("riched20.dll")
	hRAEditDll=LoadLibrary("RAEdit.dll")
	If hRAEditDll Then
		hRAFileDll=LoadLibrary("RAFile.dll")
		If hRAFileDll Then
			hRAPropertyDll=LoadLibrary("RAProperty.dll")
			If hRAPropertyDll Then
				hRACodeCompleteDll=LoadLibrary("RACodeComplete.dll")
				If hRACodeCompleteDll Then
					hRAResEdDll=LoadLibrary("RAResEd.dll")
					If hRAResEdDll Then
						hRAGridDll=LoadLibrary("RAGrid.dll")
						If hRAGridDll Then
							CharTab=Cast(Any ptr,GetProcAddress(hRAEditDll,StrPtr("GetCharTabPtr")))
							ad.lpCharTab=CharTab()
							ah.haccel=LoadAccelerators(hInstance,Cast(ZString ptr,IDA_ACCEL))
							OleInitialize(NULL)
							WinMain(hInstance,NULL,NULL,NULL)
							OleUninitialize
						Else
							MessageBox(NULL,StrPtr("Could not find RAGrid.dll"),@szAppName,MB_OK Or MB_ICONERROR)
						EndIf
						FreeLibrary(hRAResEdDll)
					Else
						MessageBox(NULL,StrPtr("Could not find RAResEd.dll"),@szAppName,MB_OK Or MB_ICONERROR)
					EndIf
					FreeLibrary(hRACodeCompleteDll)
				Else
					MessageBox(NULL,StrPtr("Could not find RACodeComplete.dll"),@szAppName,MB_OK Or MB_ICONERROR)
				EndIf
				FreeLibrary(hRAPropertyDll)
			Else
				MessageBox(NULL,StrPtr("Could not find RAProperty.dll"),@szAppName,MB_OK Or MB_ICONERROR)
			EndIf
			FreeLibrary(hRAFileDll)
		Else
			MessageBox(NULL,StrPtr("Could not find RAFile.dll"),@szAppName,MB_OK Or MB_ICONERROR)
		EndIf
		FreeLibrary(hRAEditDll)
		FreeLibrary(hRichEditDll)
	Else
		MessageBox(NULL,StrPtr("Could not find RAEdit.dll"),@szAppName,MB_OK Or MB_ICONERROR)
	EndIf
	''
	'' Program has ended
	''
	ExitProcess(0)
	End

''' Program end
'}
