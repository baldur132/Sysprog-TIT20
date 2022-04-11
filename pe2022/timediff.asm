;-----------------------------------------------------------------------------
; timediff.asm - 
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
; Authors: 	Baldur Siegel
;			Jonas Straub
;
;----------------------------------------------------------------------------

%include "syscall.inc"  ; OS-specific system call macros

; include list functions
extern  list_init
extern  list_size
extern  list_is_sorted
extern  list_add
extern  list_find
extern  list_get

;-----------------------------------------------------------------------------
; CONSTANTS
;-----------------------------------------------------------------------------

%define	BUFFER_SIZE	80
%define	ERRMSG_VALUES_LEN 48

;-----------------------------------------------------------------------------
; SECTION DATA
;-----------------------------------------------------------------------------
SECTION .data

sec_i:			db	0	; number of characters in seconds
usec_switch:	db	0	; decides whether to write into sec or usec buffer
errmsg_values:	db	"Fehler: Bitte ueberpruefen Sie die Eingabewerte", 0xA

;-----------------------------------------------------------------------------
; SECTION BSS
;-----------------------------------------------------------------------------
SECTION .bss

buffer:			resb	BUFFER_SIZE
seconds_a:		resb	20	; 2^64 results in a number with 20 characters
useconds_a:		resb	6	; any usec value over 6 characters is invalid

;-----------------------------------------------------------------------------
; SECTION TEXT
;-----------------------------------------------------------------------------
SECTION .text

        ;-----------------------------------------------------------
        ; PROGRAM'S START ENTRY
        ;-----------------------------------------------------------
        global _start:function  ; make label available to linker
_start:
        nop

read_stdin:
	; Read STDIN into buffer
	SYSCALL_4 	SYS_READ, FD_STDIN, buffer, BUFFER_SIZE
	test 	rax,rax
	jz		read_finished			; no more characters to be read

ingest_data:
	; loop through buffer until line is read
	mov		rcx,0

.ingest_data_loop:
	cmp		rax,rcx					; while loop conditional
	jb		read_stdin

	mov		sil,[buffer + rcx]		; get new character

	mov		r11b,[usec_switch]
	cmp		sil,'.'
	je		.set_usec_switch

	cmp		sil,0xA					; check for newline
	je		.write_data_to_list		; end of entry, write to list

	jmp		.ingest_data_loop

.set_usec_switch:
	mov		r11b,1
	jmp		.ingest_data_loop

.write_data_to_list:
	; convert sec and usec strings into integers and add to list 

read_finished:
	nop

.exit:
	; call system exit and return to operating system / shell
	SYSCALL_2 	SYS_EXIT, 0

.exit_failure_badvalues:
	; write error message
	SYSCALL_4 SYS_WRITE, FD_STDOUT, errmsg_values, ERRMSG_VALUES_LEN
	; call system failure
	SYSCALL_2 	SYS_EXIT, 1
;-----------------------------------------------------------------------------
; END OF PROGRAM
;-----------------------------------------------------------------------------
