;-----------------------------------------------------------------------------
; createtimediff.asm
;-----------------------------------------------------------------------------
;
; DHBW Ravensburg - Campus Friedrichshafen
;
; Vorlesung Systemnahe Programmierung (SNP)
;
;----------------------------------------------------------------------------
;
; Architecture:  x86-64
; Language:      NASM Assembly Language
;
; Author:        Baldur Siegel
;                Jonas Straub
; Created:       2022-4
;
; PURPOSE:    Calculate difference between two timevals
;
; PARAMETERS: (via register)
;             RDI - pointer to output string buffer
;             RSI - pointer to timeval
;             
;
; RETURNS:    RAX
;             Number of written bytes
;
; CLOBBERS:   RAX, RDX, R8, R9
;
;----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Section TEXT
;-----------------------------------------------------------------------------
SECTION .text

        global createtimediff:function
createtimediff:
        push  rcx
        push  rbx

func_end:
        pop   rbx
        pop   rcx
        ret
