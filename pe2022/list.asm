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

;-----------------------------------------------------------------------------
; SECTION DATA
;-----------------------------------------------------------------------------
SECTION .data

position:		dq	0	; tracks the bytes of memory offset
size:			dw	0	; represents the size of the list in elements
list_sorted:	db	0	; bool for if the list is sorted or not


;-----------------------------------------------------------------------------
; SECTION BSS
;-----------------------------------------------------------------------------
SECTION .bss

list:		resq	262144	; memory allocation for list

; List memory layout
; The list is saved in memory as a 2d array, where each timeval struct is
; written to its own index in the first array. The timeval struct itself is 
; treated as the second array. Every index in the array is 128 bits (2 qword)
; and time_t as well as suseconds_t are saved with 64 bits (1 qword).
;
; index (position)    0 (0)     1 (16)    2 (32)    3 (48)
;                  --------------------------------------------
; array 1 (bit)    |   128   |   128   |   128   |   128   |
;                  --------------------------------------------
; array 2 (bit)    | 64 | 64 | 64 | 64 | 64 | 64 | 64 | 64 |
;                  --------------------------------------------
;                   sec  usec
;
; Our implementation allows for 2^16 indexes, resulting in a list memory
; usage of 1 mebibyte (2^16 * 128bit)


;-----------------------------------------------------------------------------
; SECTION TEXT
;-----------------------------------------------------------------------------
SECTION .text


;-----------------------------------------------------------------------------
; extern void list(void)
;-----------------------------------------------------------------------------
        global list_init:function
list_init:
	push    rbp
	mov     rbp,rsp

	; your code goes here

	mov     rsp,rbp
	pop     rbp
	ret

;-----------------------------------------------------------------------------
; extern short list_size(void);
;-----------------------------------------------------------------------------
	global list_size:function
list_size:
	push    rbp
	mov     rbp,rsp

	mov		ax,[size]

	mov     rsp,rbp
	pop     rbp
	ret


;-----------------------------------------------------------------------------
; extern bool list_is_sorted(void);
;-----------------------------------------------------------------------------
	global list_is_sorted:function
list_is_sorted:
	push    rbp
	mov     rbp,rsp

	mov		al,[list_sorted]

	mov     rsp,rbp
	pop     rbp
	ret


;-----------------------------------------------------------------------------
; extern short list_add(struct timeval *tv);
;-----------------------------------------------------------------------------
	global list_add:function
list_add:
	push    rbp
	mov     rbp,rsp

	;----- save entry in list -----
	mov		rcx,[position]			; get the byte offset of list end
	mov		r8,[rdi]				; get seconds value
	mov		r9,[rdi + 8]			; get useconds value
	mov		[list + rcx],r8			; move seconds into the first part
	mov		[list + rcx + 8],r9		; move useconds into the second part
	
	;----- check if list is sorted -----
	cmp		rcx, 0
	je		.list_add_end			; skip checking if this is first entry
	cmp		[list + rcx - 16],r8	; compare previous sec to current sec
	jg		.set_list_unsorted		; last sec > current sec -> not sorted
	cmp		[list + rcx - 8],r9		; compare previous usec to cur usec
	jg		.set_list_unsorted		; last usec > cur usec -> not sorted
	
	mov		rdx,1					; list is sorted
	mov		[list_sorted],rdx
	jmp		.list_add_end

.set_list_unsorted:
	mov		rdx,0					; list is not sorted
	mov		[list_sorted],rdx

.list_add_end:
	add		rcx,16					; increment to next list entry
	mov		[position],rcx			; save position
	mov		cx,[size]
	movzx	rax, cx					; return position
	inc		cx						; increment size of list
	mov		[size],cx				; save new list size
	
 	mov     rsp,rbp
	pop     rbp
	ret


;-----------------------------------------------------------------------------
; extern short list_find(struct timeval *tv);
;-----------------------------------------------------------------------------
	global list_find:function
list_find:
	push    rbp
	mov     rbp,rsp

	;----- get parameters -----
	mov		r8,[rdi]				; get target seconds
	mov		r9,[rdi + 8]			; get target useconds

	;----- switch to binary search if list is sorted -----
	movzx	rcx,BYTE[list_sorted]
	cmp		rcx,1
	je		.bin_search

	;----- general search (linear) -----
.lin_search:
	mov		rcx, 0					; init counter
	movzx	r11,WORD[size]			; get list size

.loop_lin:
	cmp		r11,rcx					; while loop test condition
	jb		.list_find_end			; exit loop if counter is > last index

	; test timeval equality
	mov		rax,rcx
	mov		r10,16
	mul		r10						; generate byte offset inside list
	cmp		r8,[list + rax]			; compare seconds
	jne		.loop_lin_end
	cmp		r9,[list + rax + 8]		; compare useconds
	jne		.loop_lin_end

	; both seconds and useconds equal, match found
	mov		rax,rcx					; return 0-counted position
	jmp		.list_find_end

.loop_lin_end:
	inc		rcx
	jmp		.loop_lin


	;----- sorted search (binary) -----
.bin_search:
	mov		r10,0					; left value
	movzx	r11,WORD[size]			; right value
	dec		r11						; convert to 0-counted

.loop_bin:
	cmp		r10,r11					; while loop test condition
	ja		.list_find_end			; run while left <= right

	mov		rdx,0
	mov		rax,0
	mov		rcx,2
	add		rax,r10
	add		rax,r11
	div		rcx						; calculate middle value

	; comparison stage 1, seconds
	mov		rcx,16
	mul		rcx						; calc offset for list
	mov		rcx,[list + rax]		; get middle seconds value

	cmp		rcx,r8					; compare seconds
	jb		.adj_left
	ja		.adj_right

	; comparison stage 2, useconds
	mov		rcx,[list + rax + 8]	; get middle useconds value

	cmp		rcx,r9					; compare useconds
	jb		.adj_left
	ja		.adj_right

	; both comparisons succeeded, value found
	mov		rcx,16
	div		rcx						; convert value to 0-counted index
	jmp		.list_find_end

.adj_left:
	mov		rcx, 16
	div		rcx
	mov		r10,rax
	inc		r10
	jmp		.loop_bin

.adj_right:
	mov		rcx, 16
	div		rcx
	mov		r11,rax
	dec		r11
	jmp		.loop_bin


.list_find_end:
	mov     rsp,rbp
	pop     rbp
	ret


;-----------------------------------------------------------------------------
; extern bool list_get(struct timeval *tv, short idx);
;-----------------------------------------------------------------------------
	global list_get:function
list_get:
	push    rbp
	mov     rbp,rsp
	
	mov		rax,0

	;----- sanity checks -----
	mov		rcx,[size]
	cmp		rcx,0					; check if size is zero
	jz		.list_get_end			; list has no entries
	dec		rcx						; convert 1-counted value to 0-counted
	cmp		rsi,rcx					; prevent looking out of bounds
	ja		.list_get_end			; search index is larger than list
	
	;----- retrieve timeval -----
	mov		rax, rsi
	mov		rdx, 16
	mul		rdx
	mov		r8,[list + rax]			; get seconds from memory
	mov		r9,[list + rax + 8]		; get useconds from memory
	mov		[rdi],r8				; write seconds
	mov		[rdi + 8],r9			; write useconds
	mov		rax,0
	inc		rax						; return true
	jmp		.list_get_end

.list_get_end:
	mov     rsp,rbp
	pop     rbp
	ret
