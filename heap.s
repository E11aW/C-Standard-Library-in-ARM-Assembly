		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table
HEAP_TOP	EQU		0x20001000
HEAP_BOT	EQU		0x20004FE0
MAX_SIZE	EQU		0x00004000		; 16KB = 2^14
MIN_SIZE	EQU		0x00000020		; 32B  = 2^5
	
MCB_TOP		EQU		0x20006800      ; 2^10B = 1K Space
MCB_BOT		EQU		0x20006BFE
MCB_ENT_SZ	EQU		0x00000002		; 2B per entry
MCB_TOTAL	EQU		512				; 2^9 = 512 entries
	
INVALID		EQU		-1				; an invalid id
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Memory Control Block Initialization
       EXPORT  _heap_init
_heap_init
		PUSH    {R0-R12, LR}
		
		; initial values     
        MOV     R1, #0               
        LDR     R5, =MAX_SIZE

		; load top of MCB as max size, zeroing out the mcb entry
        LDR     R2, =MCB_TOP         
        STR     R5, [R2]          	; set first MCB entry to max size   
        STRB    R1, [R2, #2]        ; clear upper byte

        LDR     R3, =MCB_TOP
        ADD     R3, R3, #4           ; start address 0x20006804 to skip first entry

        LDR     R4, =0x20006C00      ; end address of MCBs

_zero_mcb_loop
        CMP     R3, R4
        BGE     _heap_init_end       ; exit if reached end of MCB
		; mark first and second bytes as free
        STRB    R1, [R3]          
        STRB    R1, [R3, #1]       
        ADD     R3, R3, #2           ; move to next 2 byte MCB entry
        B       _zero_mcb_loop

_heap_init_end
        POP     {R0-R12, LR}
        BX      LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory Allocation
; void* _k_alloc(int size)
		EXPORT 	_kalloc
_kalloc
        PUSH    {R1-R12, LR}

        LDR     R1, =MCB_TOP         ; left_mcb_addr
        LDR     R2, =MCB_BOT         ; right_mcb_addr
        BL      _ralloc              ; first recursive call

        POP     {R1-R12, LR}
        BX      LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _r_alloc(int size, left_mcb, right_mcb)
_ralloc
		SUB 	R3, R2, R1 			; right_mcb_addr - left_mcb_addr
		ADD 	R3, R3, #MCB_ENT_SZ	; make range inclusive
		; compute midpoint
		MOV 	R4, R3, LSR #1 
		ADD 	R5, R1, R4 			; midpoint = left_mcb_addr + half_mcb_addr_space
		; compute actual sizes
		MOV 	R7, R3, LSL #4 		; R3 * 16 (total)
		MOV 	R8, R4, LSL #4 		; R4 * 16 (half)
		; if (size <= act_half_size) 
		CMP 	R0, R8 							
		BGT 	_ralloc_else 		
				
		; try recursive allocation on left
		PUSH 	{R0-R8, LR} 		
		SUB 	R2, R5, #2 			; new right_mcb_addr = midpoint - 2 entries
		BL 		_ralloc				; recursively check left
		; check success
		CMP 	R0, #0
		POPEQ 	{R0-R8, LR} 
		BEQ		_ralloc_right
		POPNE 	{R1} 				; set R1 equal to new left_mcb_addr
		POPNE 	{R1-R8, LR} 

_ralloc_left 
		; mark midpoint as split
		LDR 	R9, [R5] 			; R9 = current MCB contents at midpoint
		RORS	R10, R9, #1 		; check allocation
		STRCC 	R8, [R5] 			; if not, write half size to midpoint
		B 		_ralloc_return

_ralloc_right
		; try recursive allocation on right
		MOV 	R1, R5 				; left_mcb_addr = midpoint
		PUSH	{R3-R8, LR} 		
		BL 		_ralloc 			; recursively check right
		POP 	{R3-R8, LR} 
		B 		_ralloc_return 

_ralloc_else 						
		LDR 	R9, [R1] 			; R9 = current MCB contents at left_mcb_addr
		; check if already allocated
		ANDS 	R10, R9, #1 		
		MOVNE	 R0, #0 
		BNE 	_ralloc_return 
		; check if block is large enough
		CMP 	R9, R7 
		MOVLT 	R0, #0 				; return null address if left buddy is smaller than previous midpoint
		BLT 	_ralloc_return
		
		; mark block as allocated
		ORR 	R9, R7, #1 			
		STR 	R9, [R1] 
		; compute final heap_address from mcb_index
		LDR 	R9, =MCB_TOP 
		SUB 	R0, R1, R9 			; mcb_index = mcb_addr - mcb_top
		LDR 	R9, =HEAP_TOP 
		ADD 	R0, R9, R0, LSL #4 	; heap_addr = HEAP_TOP + index * 16

_ralloc_return
		BX 		LR					; return from ralloc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory De-allocation
; void* _kfree(void* ptr)
		EXPORT _kfree
_kfree
		; initialize starting values
        PUSH    {R1-R12, LR}
        LDR     R1, =HEAP_TOP
        LDR     R2, =HEAP_BOT
		; ensure input is valid address
        CMP     R0, R1
        MOVLT   R0, #0
        BLT     _kfree_end
        CMP     R0, R2
        MOVGT   R0, #0
        BGT     _kfree_end

		; set parameters for _rfree
        LDR     R3, =MCB_TOP
        MOV     R4, R0
        SUB     R4, R4, R1           ; addr - heap_top
        LSR     R4, #4               ; divide by 16
        ADD     R3, R3, R4           ; mcb_addr = mcb_top + index
        PUSH    {R0}
        MOV     R0, R3               ; store in R0
        BL      _rfree
        POP     {R0}

_kfree_end
        POP     {R1-R12, LR}
        BX      LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _rfree(int mcb_addr)
_rfree
		LDR 	R3, [R0] 			; load mcb_contents from mcb_addr
		LDR 	R5, =MCB_TOP 
		SUB 	R4, R0, R5 			; mcb_index = mcb_addr - mcb_top
		; extract mcb_disp by removing low 4 bits and shifting
		LSR 	R3, #4 
		MOV 	R5, R3 
		LSL 	R3, #4 
		MOV 	R6, R3 
		BIC		R3, R3, #1
		STRH 	R3, [R0] 
		; determine if mcb_index is odd or even
		SDIV 	R9, R4, R5 			; mcb_index / mcb_disp
		RORS 	R9, #1 				; rotate right for carry bit
		BCS 	_rfree_odd_address 	; dealloc left buddy for odd address, or continue to right buddy

_rfree_even_address					
		; compute right buddy address: mcb_addr + mcb_disp
		MOV 	R7, R0 
		ADD 	R7, R0, R5 			
		LDR 	R8, =MCB_BOT 
		CMP 	R7, R8 				; check address validity
		MOVGE 	R0, #0 
		BGE 	_rfree_return 
		
		; deallocate and merge with right buddy if possible				
		LDRH 	R8, [R7] 
		AND 	R9, R8, #1 
		CMP 	R9, #0 				; check if buddy is free
		BNE 	_rfree_return
		; check if buddy is the same size
		LSR 	R8, #5 
		LSL 	R8, #5 
		CMP 	R8, R6
		BNE 	_rfree_return

		; clear and merge with right buddy 
		MOV 	R9, #0
		STRH 	R9, [R7]			; clear buddy mcb
		LSL 	R6, #1 				; double block size (coalesced)
		STRH 	R6 , [R0]
		; recursively merge with current mcb_addr
		PUSH 	{R0-R6, LR} 
		BL 		_rfree 
		POP 	{R0-R6, LR} 
		B 		_rfree_return
		
_rfree_odd_address
		; compute left buddy address: mcb_addr - mcb_disp
		MOV 	R7, R0 
		SUB 	R7, R7, R5 			; R7 = address of left buddy
		LDR 	R8, =MCB_TOP 
		CMP 	R7, R8 				; check address validity
		MOVLT 	R0, #0 
		BLT 	_rfree_return

		; deallocate and merge with left buddy if possible	
		LDRH 	R8, [R7] 
		AND 	R9, R8, #1
		CMP 	R9, #0 				; check if buddy is free
		BNE 	_rfree_return
		; check if buddy is the same size
		LSR 	R8, #5 
		LSL 	R8, #5
		CMP 	R8, R6
		BNE 	_rfree_return 
		
		; clear and merge with left buddy 
		MOV 	R9, #0 
		STRH 	R9, [R0] 
		LSL 	R6, #1 
		STRH 	R6, [R7] 
		; recursively merge with current mcb_addr
		PUSH 	{R0-R6, LR}
		MOV 	R0, R7
		BL 		_rfree
		POP 	{R0-R6, LR}
	
_rfree_return						
		BX 		lr					; return from rfree

        END