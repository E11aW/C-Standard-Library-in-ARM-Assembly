		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table
SYSTEMCALLTBL	EQU		0x20007B00 ; originally 0x20007500
SYS_EXIT		EQU		0x0		; address 20007B00
SYS_ALARM		EQU		0x1		; address 20007B04
SYS_SIGNAL		EQU		0x2		; address 20007B08
SYS_MEMCPY		EQU		0x3		; address 20007B0C
SYS_MALLOC		EQU		0x4		; address 20007B10
SYS_FREE		EQU		0x5		; address 20007B14

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		IMPORT	_kfree
		IMPORT	_kalloc
		IMPORT	_signal_handler
		IMPORT	_timer_start


; System Call Table Initialization
		EXPORT	_syscall_table_init
_syscall_table_init
		PUSH	{LR}
		LDR		R0, =SYSTEMCALLTBL
		PUSH	{R0}
		
		MOV		R1, #0					; SYS_EXIT
		STR		R1, [R0], #4
		
		LDR		R1, =_timer_start 		; SYS_ALARM
		STR		R1, [R0], #4
		
		LDR		R1, =_signal_handler	; SYS_SIGNAL
		STR		R1, [R0], #4
		
		MOV		R1, #0					; SYS_MEMCPY
		STR		R1, [R0], #4
		
		LDR		R1, =_kalloc			; SYS_MALLOC
		STR		R1, [R0], #4
		
		LDR		R1, =_kfree				; SYS_FREE
		STR		R1, [R0], #4
	
		POP		{R0}	; original location of SYSTEMCALLTBL
		POP		{LR}
		MOV		pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table Jump Routine
        EXPORT	_syscall_table_jump
_syscall_table_jump
		PUSH	{LR}
		; checks value at R7 in range
		CMP		R7, #1
		BLT 	end_jump
		
		; find correct table address
		LDR		R8, =SYSTEMCALLTBL
		ADD		R8, R7, LSL #2
		
		; branch to correct table address
		LDR		R9, [R8]
		BLX		R9
		
end_jump
		POP		{LR}
		MOV		pc, lr			
		
		END


		
