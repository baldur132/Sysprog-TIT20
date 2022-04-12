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

sec_i:		db	0	; number of digits in seconds
usec_i:			db	0	; tracks byte offset in usec
usec_flag:		db	0	; decides whether to write into sec or usec buffer
errmsg_values:	db	"Fehler: Bitte ueberpruefen Sie die Eingabewerte", 0xA

;-----------------------------------------------------------------------------
; SECTION BSS
;-----------------------------------------------------------------------------
SECTION .bss

buffer:			resb	BUFFER_SIZE
seconds:		resb	20	; 2^64 results in a number with 20 digits
useconds:		resb	6	; any usec value over 6 digits is invalid

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

	mov		rcx,0

;-----------------------------------------------------------------------------
; Reading and parsing incoming data 
;-----------------------------------------------------------------------------
ingest_data:
	; loop through buffer forwards until line is read
	cmp		rax,rcx					; while loop conditional
	jb		read_stdin				; buffer empty, read more

	mov		sil,[buffer + rcx]		; get new character
	movzx	rdi,BYTE[usec_flag]		; get the usec flag

	cmp		sil,0xA					; check for newline
	je		.newline_cmp			; handle newline
	cmp		sil,'.'					; check for decimal
	je		.dot_cmp				; handle decimal
	jmp		.number					; assume it's a number (we check later)

.newline_cmp:
	test	rdi,rdi
	jz		error_values			; no flag set = no usec written -> error
	dec		rdi
	mov		[usec_flag],rdi			; reset usec flag
	je		.write_data_to_list		; end of entry, write to list

.dot_cmp:
	test	rdi,rdi
	jnz		error_values			; flag set = other dot in line -> error
	inc		rdi
	mov		[usec_flag],rdi			; set usec flag
	jmp		ingest_data

.number:
	sub		sil,48					; move ascii number space to integer space
	cmp		sil,9					; check if ascii characters were numbers
	ja		error_values			; ascii characters were not numbers
	test	rdi,rdi					; check usec flag
	jz		.number_sec				; flag unset, skip usec section

	movzx	rdx,BYTE[usec_i]
	cmp		rdx,5					; prevent escaping memory
	ja		error_values			; we have read more than 6 usec digits
	mov		[useconds + rdx],sil	; write useconds
	inc		rdx
	mov		[usec_i],dl				; increment usec list iterator
	jmp		ingest_data
.number_sec:
	movzx	rdx,BYTE[usec_i]
	cmp		rdx,19					; prevent overwriting usec
	ja		error_values			; we have read more than 20 sec digits
	mov		[seconds + rdx],sil		; write seconds
	inc		rdx
	mov		[sec_i],dl				; increment sec list iterator
	jmp		ingest_data

.write_data_to_list:
	; convert sec and usec digits into integers and add to list 
	; read seconds/useconds
	;	seconds contains an array of digits 
	;	which need to be converted to one integer
	;	sec_i = 5
	;	[5,2,3,4,8,1] = 523481
	;	  				5*100000 + 2*10000 + 3*1000 + 4*100 + 8*10 + 1*1
	;	=> seconds[i] * 10^(sec_i - i)

	push	rax					; save rax as we need it to multiply
	mov		rcx,[sec_i]			; 

	pop rax

;-----------------------------------------------------------------------------
; Calculating time difference and generating timestamps 
;-----------------------------------------------------------------------------
read_finished:
	nop

.exit:
	; call system exit and return to operating system / shell
	SYSCALL_2 	SYS_EXIT, 0

error_values:
	; write error message
	SYSCALL_4 SYS_WRITE, FD_STDOUT, errmsg_values, ERRMSG_VALUES_LEN
	; call system failure
	SYSCALL_2 	SYS_EXIT, 1
;-----------------------------------------------------------------------------
; END OF PROGRAM
;-----------------------------------------------------------------------------
