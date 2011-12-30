
LCDBUFF		EQU	40h				;16 Bytes
LCDBUFFSIZE	EQU	10h

INTGRC		BIT	21h.1		;BIT SET IF INTEGER ERROR
ADD_IN		BIT	21h.3		;DCMPXZ IN BASIC BACKAGE
ZSURP		BIT	21h.6		;ZERO SUPRESSION FOR HEX PRINT
ARG_STACK	EQU	22h		;ARGUMENT STACK POINTER
FORMAT		EQU	23h		;LOCATION OF OUTPUT FORMAT BYTE
FP_STATUS	EQU	24h		;24 NOT used data pointer me
CONVT		EQU	66h		;String addr TO CONVERT NUMBERS
CR		EQU	50h
FPOUTPTR	equ	54h		;Holds address of output character
FPOUTSTR	equ	55h		;Address of output string, max 16 bytes

;RESET:***********************************************
		ORG	0000h
		LJMP	START

START:		MOV	ARG_STACK,#85h	;ARG STACK
		MOV	FORMAT,#22h	;FORMAT (##.##)
		ACALL	LCDCLEARBUFF
		ACALL	LCDINIT
		MOV	LCDBUFF,#'C'
		MOV	LCDBUFF+1,#'H'
		MOV	CR,#0Dh
START1:		MOV	A,#00h			;CH0
		ACALL	ADCONVERT
		MOV	R6,#00h
		MOV	R7,#00h
		MOV	R0,#LCDBUFF+6
		ACALL	BIN2DEC
		MOV	R0,#LCDBUFF+6
		LCALL	FLOATING_POINT_INPUT	;Convert to floating point
		MOV	DPTR,#FP5MUL
		LCALL	PUSHC
		LCALL	FLOATING_MUL
		MOV	R0,#FPOUTSTR
		MOV	FPOUTPTR,R0
		LCALL	FLOATING_POINT_OUTPUT
		MOV	R0,FPOUTPTR
		MOV	R1,#LCDBUFF+LCDBUFFSIZE-2
START2:		DEC	R0
		MOV	A,@R0
		MOV	@R1,A
		DEC	R1
		CJNE	R0,#FPOUTSTR,START2
		MOV	LCDBUFF+2,#'0'
		MOV	LCDBUFF+LCDBUFFSIZE-1,#'V'
		CLR	A
		ACALL	LCDSETADR
		MOV	R7,#10h
		MOV	R0,#LCDBUFF
		ACALL	LCDPRINTSTR

		MOV	A,#01h			;CH1
		ACALL	ADCONVERT
		MOV	R6,#00h
		MOV	R7,#00h
		MOV	R0,#LCDBUFF+6
		ACALL	BIN2DEC
		MOV	R0,#LCDBUFF+6
		LCALL	FLOATING_POINT_INPUT	;Convert to floating point
		MOV	DPTR,#FP24MUL
		LCALL	PUSHC
		LCALL	FLOATING_MUL
		MOV	R0,#FPOUTSTR
		MOV	FPOUTPTR,R0
		LCALL	FLOATING_POINT_OUTPUT
		MOV	R0,FPOUTPTR
		MOV	R1,#LCDBUFF+LCDBUFFSIZE-2
START3:		DEC	R0
		MOV	A,@R0
		MOV	@R1,A
		DEC	R1
		CJNE	R0,#FPOUTSTR,START3
		MOV	LCDBUFF+2,#'1'
		MOV	LCDBUFF+LCDBUFFSIZE-1,#'V'
		MOV	A,#40h
		ACALL	LCDSETADR
		MOV	R7,#10h
		MOV	R0,#LCDBUFF
		ACALL	LCDPRINTSTR

		MOV	R5,#10h
		MOV	R6,#00h
		MOV	R7,#00h
START4:		DJNZ	R7,START4
		DJNZ	R6,START4
		DJNZ	R5,START4
		AJMP	START1

;------------------------------------------------------------------
;AD Converter.
;IN:	A holds channel (0 to 7).
;OUT:	R5:R4 Holds 16 Bit result
;-----------------------------------------------------
ADCONVERT:	ORL	A,#18h				;START, SINGLE ENDED
		RL	A
		RL	A
		RL	A
		CLR	P1.0				;CS	LOW
		;Clock in start bit, 3 channel select bits, Single/Diff bit
		;and 2 bits to init sampling
		MOV	R7,#07h
ADCONVERT1:	RLC	A
		MOV	P1.2,C				;DIN
		CLR	P1.1				;CLK	LOW
		SETB	P1.1				;CLK	HIGH
		DJNZ	R7,ADCONVERT1
		SETB	P1.2				;DIN	HIGH
		;Clock out 1 null bit and 4 data bits
		CLR	A
		MOV	R7,#05h
ADCONVERT2:	MOV	C,P1.3				;DOUT
		RLC	A
		CLR	P1.1				;CLK	LOW
		SETB	P1.1				;CLK	HIGH
		DJNZ	R7,ADCONVERT2
		MOV	R5,A
		;Clock out 8 data bits
		MOV	R7,#08h
		CLR	A
ADCONVERT3:	MOV	C,P1.3				;DOUT
		RLC	A
		CLR	P1.1				;CLK	LOW
		SETB	P1.1				;CLK	HIGH
		DJNZ	R7,ADCONVERT3
		MOV	R4,A
		SETB	P1.0				;CS	HIGH
		RET

;------------------------------------------------------------------
;LCD Output.
;------------------------------------------------------------------
LCDDELAY:	PUSH	07h
		MOV	R7,#00h
		DJNZ	R7,$
		POP	07h
		RET

;A contains nibble, ACC.4 contains RS
LCDNIBOUT:	SETB	ACC.5				;E
		MOV	P2,A
		CLR	P2.5				;Negative edge on E
		RET

;A contains byte
LCDCMDOUT:	PUSH	ACC
		SWAP	A				;High nibble first
		ANL	A,#0Fh
		ACALL	LCDNIBOUT
		POP	ACC
		ANL	A,#0Fh
		ACALL	LCDNIBOUT
		ACALL	LCDDELAY			;Wait for BF to clear
		RET

;A contains byte
LCDCHROUT:	PUSH	ACC
		SWAP	A				;High nibble first
		ANL	A,#0Fh
		SETB	ACC.4				;RS
		ACALL	LCDNIBOUT
		POP	ACC
		ANL	A,#0Fh
		SETB	ACC.4				;RS
		ACALL	LCDNIBOUT
		ACALL	LCDDELAY			;Wait for BF to clear
		RET

LCDCLEAR:	MOV	A,#00000001b
		ACALL	LCDCMDOUT
		MOV	R7,#00h
LCDCLEAR1:	ACALL	LCDDELAY
		DJNZ	R7,LCDCLEAR1
		RET

;A contais address
LCDSETADR:	ORL	A,#10000000b
		ACALL	LCDCMDOUT
		RET

;R0 points to string, R7 holds number of characters
LCDPRINTSTR:	MOV	A,@R0
		ACALL	LCDCHROUT
		INC	R0
		DJNZ	R7,LCDPRINTSTR
		RET

PRNTCDPTRLCD:	CLR	A
		MOVC	A,@A+DPTR
		JZ	PRNTCDPTRLCD1
		ACALL	LCDCHROUT
		INC	DPTR
		SJMP	PRNTCDPTRLCD
PRNTCDPTRLCD1:	RET

LCDINIT:	MOV	A,#00000011b			;Function set
		ACALL	LCDNIBOUT
		ACALL	LCDDELAY			;Wait for BF to clear
		MOV	A,#00101000b
		ACALL	LCDCMDOUT
		MOV	A,#00101000b
		ACALL	LCDCMDOUT
		MOV	A,#00001100b			;Display ON/OFF
		ACALL	LCDCMDOUT
		ACALL	LCDCLEAR			;Clear
		MOV	A,#00000110b			;Cursor direction
		ACALL	LCDCMDOUT
		RET

LCDCLEARBUFF:	MOV	R0,#LCDBUFF
		MOV	R7,#10h
		MOV	A,#20H
LCDCLEARBUFF1:	MOV	@R0,A
		INC	R0
		DJNZ	R7,LCDCLEARBUFF1
		RET

;------------------------------------------------------------------
;Binary to decimal converter
;Converts R7:R6:R5:R4 to decimal pointed to by R0
;Returns with number of digits in A
;------------------------------------------------------------------
BIN2DEC:	PUSH	00h
		MOV	DPTR,#BINDEC
		MOV	R2,#0Ah
BIN2DEC1:	MOV	R3,#2Fh
BIN2DEC2:	INC	R3
		ACALL	SUBIT
		JNC	BIN2DEC2
		ACALL	ADDIT
		MOV	A,R3
		MOV	@R0,A
		INC	R0
		INC	DPTR
		INC	DPTR
		INC	DPTR
		INC	DPTR
		DJNZ	R2,BIN2DEC1
		POP	00h
		;Remove leading zeroes
		MOV	R2,#09h
BIN2DEC3:	MOV	A,@R0
		CJNE	A,#30h,BIN2DEC4
		MOV	@R0,#20h
		INC	R0
		DJNZ	R2,BIN2DEC3
BIN2DEC4:	INC	R2
		MOV	A,R2
		RET

SUBIT:		CLR	A
		MOVC	A,@A+DPTR
		XCH	A,R4
		CLR	C
		SUBB	A,R4
		MOV	R4,A
		MOV	A,#01h
		MOVC	A,@A+DPTR
		XCH	A,R5
		SUBB	A,R5
		MOV	R5,A
		MOV	A,#02h
		MOVC	A,@A+DPTR
		XCH	A,R6
		SUBB	A,R6
		MOV	R6,A
		MOV	A,#03h
		MOVC	A,@A+DPTR
		XCH	A,R7
		SUBB	A,R7
		MOV	R7,A
		RET

ADDIT:		CLR	A
		MOVC	A,@A+DPTR
		ADD	A,R4
		MOV	R4,A
		MOV	A,#01h
		MOVC	A,@A+DPTR
		ADDC	A,R5
		MOV	R5,A
		MOV	A,#02h
		MOVC	A,@A+DPTR
		ADDC	A,R6
		MOV	R6,A
		MOV	A,#03h
		MOVC	A,@A+DPTR
		ADDC	A,R7
		MOV	R7,A
		RET

BINDEC:		DB	000h,0CAh,09Ah,03Bh		;1000000000
		DB	000h,0E1h,0F5h,005h		; 100000000
		DB	080h,096h,098h,000h		;  10000000
		DB	040h,042h,0Fh,0000h		;   1000000
		DB	0A0h,086h,001h,000h		;    100000
		DB	010h,027h,000h,000h		;     10000
		DB	0E8h,003h,000h,000h		;      1000
		DB	064h,000h,000h,000h		;       100
		DB	00Ah,000h,000h,000h		;        10
		DB	001h,000h,000h,000h		;         1

FP5MUL:		DB	7Eh,00h,13h,00h,21h,12h		;5.0/4095= 0.0012210012
FP24MUL:	DB	7Eh,00h,59h,80h,60h,58h		;24.0/4095=0.0058608059

		ORG	1000h

$include	(FP52INT.a51)

		END
