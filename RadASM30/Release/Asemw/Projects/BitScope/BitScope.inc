
;-----------------------------------------------------
;*****************************************************
;Equates
;-----------------------------------------------------
T2CON		EQU 0C8h
RCAP2L		EQU 0CAh
RCAP2H		EQU 0CBh
TL2		EQU 0CCh
TH2		EQU 0CDh
USBIO		EQU 8003h
USBRXF		EQU P3.2
USBTXE		EQU P3.4
;-----------------------------------------------------
;Adresses in internal ram
INTBITS		EQU 20h			;Interrupt jump control
ROMBUFF		EQU 40h			;16 Bytes
DPLSAVE		EQU 57h			;Holds DPL during PRNTCSTR
DPHSAVE		EQU 58h			;Holds DPH during PRNTCSTR
SSADRLSB	EQU 5Ah			;Single step adress LSB
SSADRMSB	EQU 5Bh			;Single step adress MSB