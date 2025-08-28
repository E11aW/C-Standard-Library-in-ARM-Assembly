		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Timer Definition
STCTRL		EQU		0xE000E010		; SysTick Control and Status Register
STRELOAD	EQU		0xE000E014		; SysTick Reload Value Register
STCURRENT	EQU		0xE000E018		; SysTick Current Value Register
	
STCTRL_STOP	EQU		0x00000004		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 0, Bit 0 (ENABLE) = 0
STCTRL_GO	EQU		0x00000007		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 1, Bit 0 (ENABLE) = 1
STRELOAD_MX	EQU		0x00FFFFFF		; MAX Value = 1/16MHz * 16M = 1 second
STCURR_CLR	EQU		0x00000000		; Clear STCURRENT and STCTRL.COUNT	
SIGALRM		EQU		14				; sig alarm

; System Variables
SECOND_LEFT	EQU		0x20007B80		; Seconds left for alarm( )
USR_HANDLER EQU		0x20007B84		; Address of a user-given signal handler function	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer initialization
; void timer_init( )
		EXPORT		_timer_init
_timer_init
		PUSH	{LR}
		; stopping system timer
		LDR		R0, =STCTRL
		LDR		R1, =STCTRL_STOP
		STR		R1, [R0]		
		
		; setting reload value to max
		LDR		R0, =STRELOAD
		LDR		R1, =STRELOAD_MX
		STR		R1, [R0]	

		; clearing current
		LDR		R0, =STCURRENT
		MOV		R1, #0
		STR		R1, [R0]
		
		POP		{LR}
		MOV		pc, lr		; return to Reset_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer start
; int timer_start( int seconds )
		EXPORT		_timer_start
_timer_start
		PUSH	{LR}
		; storing seconds argument into number of seconds left
		LDR		R7, =SECOND_LEFT
		STR		R0, [R7]
		
		; clear current SysTick timer
		LDR		R8, =STCURRENT
		LDR		R9, =STCURR_CLR
		STR		R9, [R8]
		
		; starts SysTick
		LDR		R8, =STCTRL
		LDR		R9, =STCTRL_GO
		STR		R9, [R8]
		
		POP		{LR}
		MOV		pc, lr		; return to SVC_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void timer_update( )
		EXPORT		_timer_update
_timer_update
		PUSH	{LR}
		
		LDR		R0, =SECOND_LEFT
		LDR		R1, [R0]
		SUBS	R1, R1, #1
		STR		R1, [R0]
		BNE		_timer_update_done
		
		; stopping system timer
		LDR		R2, =STCTRL
		LDR		R3, =STCTRL_STOP
		STR		R3, [R2]
		
		; branch to user handler
		LDR		R4, =USR_HANDLER
		LDR		R5, [R4]
		BLX		R5
_timer_update_done
		POP		{LR}	
		MOV		pc, lr		; return to SysTick_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void* signal_handler( int signum, void* handler )
	    EXPORT	_signal_handler
_signal_handler
		PUSH	{LR}
		; checking value of sig (R0)
		LDR		R8, =SIGALRM		; loads register with #14
		CMP		R8, R0
		BNE		wrong_signal		; does not store function if wrong signal
		
		; store signal in user handler
		LDR		R9, =USR_HANDLER
		LDR		R0, [R9]			; sets return value in R0
		STR		R1, [R9]
		
wrong_signal	
		POP		{LR}	
		MOV		pc, lr		; return to Reset_Handler
		
		END		
