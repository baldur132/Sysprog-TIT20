;-----------------------------------------------------------------------------
; uint_to_ascii64.asm
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
; Author:        Ralf Reutemann
; Created:       2021-12-02
;
; PURPOSE:    Convert timeval into string
;
; PARAMETERS: (via register)
;             RDI - pointer to output string buffer
;             RSI - pointer to timeval
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

        global timevaltostring:function
timevaltostring:
        push  rcx
        push  rbx

        mov   rax,QWORD[rsi]
        call  secondstostring

        ; insert seconds useconds separator
        mov   BYTE[rdi + rax],'.'
        add   rdi,rax
        inc   rax
        mov   r8,rax

        mov   rax,QWORD[rsi + 8]
        call  usecondstostring

        ; insert seconds useconds separator
        add   r8,6
        mov   BYTE[rdi + 6],0xA
        mov   rax,r8

        jmp   func_end

secondstostring:
        mov   rcx,0   ; loop counter
        mov   rbx,10   ; divisor
        test  rax,rax
        jnz   .loop

        mov   byte[rdi],'0'
        mov   rbx,1
        jmp   .reverse_end

.loop:
        test  rax,rax
        jz    .reverse

        xor   rdx,rdx   ; clear rdx
        div   rbx
        add   dl,'0'    ; bring into ascii number space
        mov   [rdi+rcx],dl
        inc   rcx
        jmp   .loop

.reverse:
        dec   rcx
        mov   rax,rcx   ; set rax as iteration limit
        xor   rdx,rdx   ; clear rdx 
        test  al,0x01   ; test for uneven numbers
        jne   .reverse_loop_start
        mov   dl,0x01
.reverse_loop_start:
        shr   rax,1      ; divide by 2
        mov   rbx,0      ; iterator

.reverse_loop:
        cmp   rcx, rax
        je    .reverse_end
        xor   r8,r8
        xor   r9,r9
        mov   r8b,BYTE[rdi+rbx] ; first element
        mov   r9b,BYTE[rdi+rcx] ; last element
        mov   BYTE[rdi+rbx],r9b
        mov   BYTE[rdi+rcx],r8b
        dec   rcx
        inc   rbx
        jmp   .reverse_loop

.reverse_end:
        shl   rbx, 1    ; multiply by 2
        or    rbx,rdx   ; increase by 1 for uneven values
        mov   rax,rbx   ; return written bytes
        ret

usecondstostring:
        mov   rcx,5     ; loop counter
        mov   rbx,10    ; divisor
        test  rax,rax
        jnz   .loop
        jmp   .pad
.loop:
        test  rax,rax
        jz    .pad
        xor   rdx,rdx   ; clear rdx
        div   rbx
        add   dl,'0'    ; bring into ascii number space
        mov   [rdi+rcx],dl
        loop  .loop

.pad:
        test  rcx,rcx
        jz    .end
        mov   BYTE[rdi+rcx],'0'
        loop  .pad

.end:
        ret

func_end:

        pop   rbx
        pop   rcx
        ret
