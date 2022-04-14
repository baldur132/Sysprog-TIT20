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

; string functions
extern	timevaltostring
extern	createtimediff

;-----------------------------------------------------------------------------
; CONSTANTS
;-----------------------------------------------------------------------------

%define	BUFFER_SIZE	80

;-----------------------------------------------------------------------------
; SECTION DATA
;-----------------------------------------------------------------------------
SECTION .data

sec_i:		db	0	; number of digits in seconds
usec_i:		db	0	; tracks byte offset in usec
usec_flag:	db	0	; decides whether to write into sec or usec
emsg_values:	db	"Fehler Bitte ueberpruefen Sie die Eingabewerte", 0xA
emsg_empty:	db	"Keine Eingabewerte vorhanden", 0xA
emsg_unsorted:	db	"Eingabewerte sind nicht sortiert", 0xA


; Max length of output:
;
; 20c seconds(2^64)    7c usec 1c  => 28
; 18446744073709551616 .999999 \n
;
; 15c days        1c 5c    1c 8c time  7c usec 1c  =>  38
; 213503982334601 \s days, \s 23:59:59 .999999 \n
;
; 7c sep  1c  => 8 (total: 74)
; ======= \n
timestamp:	times	74	db	0
separator:	db	"=======", 0xA

;-----------------------------------------------------------------------------
; SECTION BSS
;-----------------------------------------------------------------------------
SECTION .bss

spacer:		resb	6
buffer:		resb	BUFFER_SIZE	; used to read input
timeval:	resq	2	; timeval to pass to list functions
seconds:	resb	20	; 2^64 results in a number with 20 digits
useconds:	resb	6	; any usec value over 6 digits is invalid

;-----------------------------------------------------------------------------
; SECTION TEXT
;-----------------------------------------------------------------------------
SECTION .text

        ;-----------------------------------------------------------
        ; PROGRAM'S START ENTRY
        ;-----------------------------------------------------------
        global _start:function  ; make label available to linker
_start:
	

read_stdin:
	; Read STDIN into buffer
	SYSCALL_4 SYS_READ, FD_STDIN, buffer, BUFFER_SIZE
	test 	rax,rax
	jz	read_finished		; no more characters to be read

	mov	r8,0			; clear iterator

;-----------------------------------------------------------------------------
; Reading and parsing incoming data 
;-----------------------------------------------------------------------------
ingest_data:
	; loop through buffer forwards until line is read
	cmp	rax,r8			; while loop conditional
	jbe	read_stdin		; buffer empty, read more

	movzx	rsi,BYTE[buffer + r8]	; get new character
	movzx	rdi,BYTE[usec_flag]	; get the usec flag

	cmp	rsi,0xA			; check for newline
	je	.newline_cmp		; handle newline
	cmp	rsi,'.'			; check for decimal
	je	.dot_cmp		; handle decimal
	jmp	.number			; assume it's a number(we check later)

.newline_cmp:
	test	rdi,rdi
	jz	error_values		; no flag set = no usecs read -> error
	dec	rdi
	mov	[usec_flag],rdi		; reset usec flag
	call	write_data_to_list	; end of entry, write to list
	jmp	.ingest_data_end

.dot_cmp:
	test	rdi,rdi
	jnz	error_values		; flag set = other dot read -> error
	inc	rdi
	mov	[usec_flag],rdi		; set usec flag
	jmp	.ingest_data_end

.number:
	sub	rsi,48			; move ascii number space to int space
	cmp	rsi,9			; check if ascii characters = numbers
	ja	error_values		; ascii characters were not numbers
	test	rdi,rdi			; check usec flag
	jz	.number_sec		; flag unset, skip usec section

	movzx	rdx,BYTE[usec_i]
	cmp	rdx,5			; prevent escaping memory
	ja	error_values		; we have read more than 6 usec digits
	mov	[useconds + rdx],rsi	; write useconds
	inc	rdx
	mov	[usec_i],dl		; increment usec list iterator
	jmp	.ingest_data_end
.number_sec:
	movzx	rdx,BYTE[sec_i]
	cmp	rdx,19			; prevent overwriting usec
	ja	error_values		; we have read more than 20 sec digits
	mov	[seconds + rdx],rsi	; write seconds
	inc	rdx
	mov	[sec_i],dl		; increment sec list iterator
	jmp	.ingest_data_end

.ingest_data_end:
	inc	r8
	jmp	ingest_data

write_data_to_list:
	; convert sec and usec digits into integers and add to list 
	; read seconds/useconds
	; seconds contains an array of digits 
	; which need to be converted to one integer
	; sec_i = 5
	; [5,2,3,4,8,1] = 523481
	;                 5*100000 + 2*10000 + 3*1000 + 4*100 + 8*10 + 1*1
	; => seconds[i] * 10^(sec_i - i)

	push	rax			; save rax as we clobber it later
	push	r8

	movzx	rcx,BYTE[sec_i]		; set length of seconds as iterator
	mov	r9,0			; forward iterator
	mov	r10,0			; clear total seconds register
	mov	r11,0			; clear total useconds register
.loop_sec:
	dec	rcx
	mov	edi,10			; set base
	mov	esi,ecx			; set exponent
	call	ipown			; get 10^sec_i into rax
	movzx	rdx,BYTE[seconds + r9]	; read digit
	mul	rdx			; calc seconds[i] * 10^sec_i
	add	r10,rax			; add result to total
	inc	r9
	test	rcx,rcx
	jnz	.loop_sec		; allow 0th iteration

	mov	rcx,6			; set iterator for usec
	mov	r9,0
.loop_usec:
	dec	rcx
	mov	edi,10			; set base
	mov	esi,ecx			; set exponent
	call	ipown			; get 10^rcx into rax
	movzx	rdx,BYTE[useconds + r9]	; 
	mul	rdx			; calc useconds[i] * 10^rcx
	add	r11,rax			; add result to total
	mov	BYTE[useconds + r9],0	; clear number in buffer
	inc	r9
	test	rcx,rcx
	jnz	.loop_usec		; allow 0th iteration

	;----- write seconds and useconds to list -----
	mov	[timeval],r10		; write seconds to mem
	mov	[timeval + 8],r11	; write useconds to mem
	mov	rdi,timeval		; write pointer to param 1
	call	list_add		; clobbers

	;----- check that the list is sorted -----
;	call	list_is_sorted
;	test	rax,rax
;	jz	error_unsorted

	; clear buffer iterators
	mov	BYTE[sec_i],0
	mov	BYTE[usec_i],0

	pop	r8
	pop	rax
	ret

ipown:
	; This power function is naive but it works.
	; rsi: base	rdi: exponent
	; returns in rax
	; clobbers: rax, rdi, rsi
	mov	rax,1
	test	rsi,rsi
	jz	.zero_exponent
.loop:
	mul	rdi
	dec	rsi
	test	rsi,rsi
	jz	.zero_exponent
	jmp	.loop

.zero_exponent:
	ret

;-----------------------------------------------------------------------------
; Calculating time difference and generating timestamps 
;-----------------------------------------------------------------------------
read_finished:
	nop

print_timestamps:
	push	r12
	call	list_size		; get number of timestamps to print
	mov	r12,rax
	mov	r11,0			; iterator
	test	r12,r12
	jz	error_empty
.print_loop:
	; 
	cmp	r11,r12			; iterator test
	jae	.print_end		; exit print

	; get timeval from list
	mov	rdi,timeval
	mov	rsi,r11
	call	list_get

	; convert timeval to string
	mov	rax,0
	mov	rdi,timestamp
	mov	rsi,timeval
	call	timevaltostring

	; calculate time difference


	; print timestamp
	push	r11
	SYSCALL_4 SYS_WRITE, FD_STDOUT, timestamp, rax
	pop	r11

.print_loop_end:
	inc	r11
	jmp	.print_loop

.print_end:
	pop	r12

exit:
	; call system exit and return to operating system / shell
	SYSCALL_2 SYS_EXIT, 0

error_unsorted:
	; write error message
	SYSCALL_4 SYS_WRITE, FD_STDOUT, emsg_unsorted, 33
	jmp	exit_failure

error_empty:
	; write error message
	SYSCALL_4 SYS_WRITE, FD_STDOUT, emsg_empty, 37
	jmp	exit_failure

error_values:
	; write error message
	SYSCALL_4 SYS_WRITE, FD_STDOUT, emsg_values, 48

exit_failure:
	; call system failure
	SYSCALL_2 SYS_EXIT, 1
;-----------------------------------------------------------------------------
; END OF PROGRAM
;-----------------------------------------------------------------------------
