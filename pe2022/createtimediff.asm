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
;             RSI - pointer to old timeval
;             RDX - pointer to current timeval
;
; RETURNS:    RAX
;             Number of written bytes
;
; CLOBBERS:   RAX, RDX, R8, R9
;
;----------------------------------------------------------------------------

; Output format:
; xxx day(s), HH:mm:SS.000000

;-----------------------------------------------------------------------------
; Section DATA
;-----------------------------------------------------------------------------
SECTION .data

secs:       db  0
mins:       db  0
hours:      db  0
usecs_adj:  db  0
days_sep:   db  " days, "
days_len:   db  7
day_sep:    db  " day, "
day_len:    db  6
time_str:   db  "00:00:00."
usec_str:   db  "000000"

;-----------------------------------------------------------------------------
; Section TEXT
;-----------------------------------------------------------------------------
SECTION .text

        global createtimediff:function
createtimediff:
        push  rbx

        ;----- calculate large difference -----
        mov   r8,rdx        ; save pointer, as it gets clobbered later
        mov   rax,[rdx]     ; grab current seconds value
        mov   rbx,60        ; divisor

        sub   rax,[rsi]     ; calculate seconds difference
        xor   rdx,rdx
        div   rbx           ; divide by 60 to get seconds in rdx
        mov   BYTE[secs],dl ; save seconds
        xor   rdx,rdx
        div   rbx           ; divide by 60 to get minutes in rdx
        mov   BYTE[mins],dl ; save minutes
        mov   rbx,24        ; update divisor
        xor   rdx,rdx
        div   rbx           ; divide to get hours in rdx (and days in rax)
        mov   BYTE[hours],dl
        mov   rdx,r8        ; free up r8

        ;----- calculate usecs and adjust time -----
        mov   rcx,[rdx + 8] ; grab current usecs
        mov   r8,[rsi + 8]  ; grab old usecs
        cmp   rcx,r8        ; compare old usecs
        jae   .substract_normal
        ; current < old, we have to adjust seconds
        mov   rcx,1000000
        sub   rcx,r8
        mov   [usecs_adj],rcx
        movzx rcx,BYTE[secs]
        test  rcx,rcx       ; see if we can subtract secs
        jnz   .subtract_secs
        ; secs = 0, we have to remove a minute
        mov   rcx,59
        movzx rcx,BYTE[mins]
        test  rcx,rcx
        jnz   .subtract_mins
        ; mins = 0, we have to remove an hour
        mov   rcx,59
        movzx rcx,BYTE[hours]
        test  rcx,rcx
        jnz   .subtract_hours
        ; hours = 0, we have to remove a day
        mov   rcx,23
        mov   rcx,rax
        jmp   .tostring

.subtract_hours:
        dec   rcx
        mov   BYTE[mins],cl
        jmp   .tostring

.subtract_mins:
        dec   rcx
        mov   BYTE[mins],cl
        jmp   .tostring

.subtract_secs:
        dec   rcx
        mov   BYTE[secs],cl
        jmp   .tostring

.substract_normal:
        ; current >= old, we can subtract normally
        sub   rax,[rsi + 8]
        mov   [usecs_adj],rax

.tostring:
        call  daystostring

        call  insert_time

        call  usecondstostring

        call  export_time

        mov   BYTE[rdi + rax],0xA
        inc   rax

        jmp   func_end

daystostring:
        mov   rcx,0   ; loop counter
        mov   rbx,10   ; divisor
        test  rax,rax
        jnz   .loop
        jmp   .end_days

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
        shl   rbx,1     ; multiply by 2
        or    rbx,rdx   ; increase by 1 for uneven values
        mov   rax,rbx   ; return written bytes

        ; decide whether there is more than 1 day
        cmp   rax,1
        jne   .insert_label
        mov   rdx,[rdi]
        cmp   rax,49    ; "1" was printed, days is singular
        je    .insert_label_singular

.insert_label:
        movzx rcx,BYTE[days_len]
        lea   rbx,[rdi + rax]
        add   rax,rcx
.label_loop:
        dec   rcx
        movzx rdx,BYTE[days_sep + rcx]
        mov   BYTE[rbx + rcx],dl
        test  rcx,rcx
        jnz   .label_loop
        jmp   .end_days

.insert_label_singular:
        movzx rcx,BYTE[day_len]
        lea   rbx,[rdi + rax]
        add   rax,rcx
.label_loop_singlular:
        movzx rdx,BYTE[day_sep + rcx]
        mov   BYTE[rbx + rcx],dl
        loop  .label_loop
        jmp   .end_days

.end_days:
        ret

insert_time:
        mov   r9,rax     ; save byte counter
        mov   rbx,10     ; divisor
        ; hours
        movzx rax,BYTE[hours]
        xor   rdx,rdx
        div   rbx
        add   dl,'0'     ; ones place
        mov   [time_str + 1],dl
        xor   rdx,rdx
        div   rbx
        add   dl,'0'     ; tens place
        mov   [time_str],dl
    
        ; minutes
        movzx rax,BYTE[mins]
        xor   rdx,rdx
        div   rbx
        add   dl,'0'     ; ones place
        mov   [time_str + 4],dl
        xor   rdx,rdx
        div   rbx
        add   dl,'0'     ; tens place
        mov   [time_str + 3],dl

        ; seconds
        movzx rax,BYTE[secs]
        xor   rdx,rdx
        div   rbx
        add   dl,'0'     ; ones place
        mov   [time_str + 7],dl
        xor   rdx,rdx
        div   rbx
        add   dl,'0'     ; tens place
        mov   [time_str + 6],dl

        mov    rax,r9
        ret

usecondstostring:
        mov   r8,rax    ; save byte counter
        mov   rcx,6     ; loop counter
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
        mov   BYTE[usec_str+rcx],dl
        loop  .loop
.pad:
        test  rcx,rcx
        jz    .end_usecs
        mov   BYTE[rdi+rcx],'0'
        loop  .pad
.end_usecs:
        mov   r8,rax
        ret

export_time:
        mov   rcx,15
        lea   rbx,[rdi + rax]
        add   rax,15
.loop_time:
        dec   rcx
        movzx rdx,BYTE[time_str + rcx]
        mov   BYTE[rbx + rcx],dl
        test  rcx,rcx
        jnz   .loop_time
        ret

func_end:
        pop   rbx
        ret
