		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

		IMPORT		SVC_Handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _bzero( void *s, int n )
; Parameters
;	s 		- pointer to the memory location to zero-initialize
;	n		- a number of bytes to zero-initialize
; Return value
;   none
		EXPORT	_bzero
_bzero
		; r0 = s
		; r1 = n
		; r2 = 0
		STMFD 	sp!, {r1-r12,lr}
		MOV 	r3, r0 				; r3 = dest
		MOV 	r2, #0 				; r2 = 0;
_bzero_loop 						; while( ) {
		SUBS 	r1, r1, #1 			; n--;
		BMI 	_bzero_return 		; if ( n < 0 ) break;
		STRB 	r2, [r0], #0x1 		; [s++] = 0;
		B 		_bzero_loop 			; }
_bzero_return
		MOV 	r0, r3 				; return dest;
		LDMFD 	sp!, {r1-r12,lr}
		MOV 	pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; char* _strncpy( char* dest, char* src, int size )
; Parameters
;   dest 	- pointer to the buffer to copy to
;	src	- pointer to the zero-terminated string to copy from
;	size	- a total of n bytes
; Return value
;   dest
		EXPORT	_strncpy
_strncpy
		; r0 = dest
		; r1 = src
		; r2 = size
		; r3 = a copy of original dest
		; r4 = src[i]
		STMFD 	sp!, {r1-r12,lr}
		MOV 	r3, r0 				; r3 = dest
_strncpy_loop 						; while( ) {
		SUBS 	r2, r2, #1 			; size--;
		BMI 	_strncpy_return 	; if ( size < 0 ) break;
		LDRB 	r4, [r1], #0x1 		; r4 = [src++];
		STRB 	r4, [r0], #0x1 		; [dest++] = r4;
		CMP 	r4, #0 ;
		BEQ 	_strncpy_return 	; if ( r4 = '\0' ) break;
		B 		_strncpy_loop 		; }
_strncpy_return
		MOV 	r0, r3 				; return dest;
		LDMFD 	sp!, {r1-r12,lr}
		MOV 	pc, lr

		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _malloc( int size )
; Parameters
;	size	- #bytes to allocate
; Return value
;   	void*	a pointer to the allocated space
		EXPORT	_malloc
_malloc
		; save registers
		STMFD 	sp!, {r1-r12,lr}
		MOV		R7, #4
		; set the system call # to R7
	    SVC     #0x4			; changed to #4 to accomadate space for memcpy
		; resume registers
		LDMFD 	sp!, {r1-r12,lr}
		MOV		pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _free( void* addr )
; Parameters
;	size	- the address of a space to deallocate
; Return value
;   	none
		EXPORT	_free
_free
		; save registers
		STMFD 	sp!, {r1-r12,lr}
		MOV		R7, #5
		; set the system call # to R7
        SVC     #0x5			; changed to #5 to accomadate space for memcpy
		; resume registers
		LDMFD 	sp!, {r1-r12,lr}
		MOV		pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; unsigned int _alarm( unsigned int seconds )
; Parameters
;   seconds - seconds when a SIGALRM signal should be delivered to the calling program	
; Return value
;   unsigned int - the number of seconds remaining until any previously scheduled alarm
;                  was due to be delivered, or zero if there was no previously schedul-
;                  ed alarm. 
		EXPORT	_alarm
_alarm
		; save registers
		STMFD 	sp!, {r1-r12,lr}
		MOV		R7, #1
		; set the system call # to R7
        SVC     #0x1
		; resume registers	
		LDMFD 	sp!, {r1-r12,lr}
		MOV		pc, lr		
			
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _signal( int signum, void *handler )
; Parameters
;   signum - a signal number (assumed to be 14 = SIGALRM)
;   handler - a pointer to a user-level signal handling function
; Return value
;   void*   - a pointer to the user-level signal handling function previously handled
;             (the same as the 2nd parameter in this project)
		EXPORT	_signal
_signal
		; save registers
		STMFD 	sp!, {r1-r12,lr}
		MOV		R7, #2
		; set the system call # to R7
        SVC     #0x2
		; resume registers
		LDMFD 	sp!, {r1-r12,lr}
		MOV		pc, lr	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EXTRA CREDIT IMPLEMENTATIONS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; int _strcmp(string str1, string str2)
	; R0 = str1
	; R1 = str2
	; R2 = str1[i]
	; R3 = str2[i]
	
		EXPORT _strcmp
_strcmp
		PUSH	{R1-R12, LR}
		
_strcmp_loop
		LDRB	R2, [R0], #1				; getting character at next index of str1
		LDRB	R3, [R1], #1				; getting character at next index of str2
		; checking if characters are equal
		CMP		R2, R3
		BNE		_strcmp_not_equal
		CMP		R2, #0						; test if at end of string
		BNE		_strcmp_loop
		
		MOV		R0, #0						; value of zero means they are equal
		B		_strcmp_return

_strcmp_not_equal
		SUB		R0, R2, R3					; return *str1 - *str2
		
_strcmp_return
		POP		{R1-R12, LR}
		BX		LR		

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; int atoi(string str)
	; R0 = str
	; R1 = current result
	; R2 = sign
	; R3 = current char
	; R4 = temp digit
	
		EXPORT	_atoi
_atoi
		PUSH	{R1-R12, LR}
		
		; set starting values
		MOV		R1, #0
		MOV		R2, #0						; starting positive
		MOV		R5, #10						; save #10 to be used later

_atoi_skip_white_spaces
		LDRB	R3, [R0], #1
		CMP		R3, #' '					; comparing with value of a white space
		BEQ		_atoi_skip_white_spaces		; keep skipping values until no more white spaces
		SUB		R0, R0, #1					; step back after non-white space
		
_atoi_check_sign
		LDRB	R3, [R0], #1
		CMP		R3, #'-'					; compare with value of negative sign
		BNE		_atoi_loop
		MOV		R2, #1						; set negative
		
_atoi_loop
		LDRB	R3, [R0], #1				; load next digit
		SUB		R4, R3, #'0'
		CMP		R4, #9
		BHI		_atoi_done
		
		; add each digit to result
		MUL		R1, R1, R5					; shift digits left to make room for new digit
		ADD		R1, R1, R4					; add new digit
		B		_atoi_loop

_atoi_done
		CMP		R2, #0						; check sign
		MOVEQ	R0, R1						; positive result
		RSBSNE	R0, R1, #0					; negative result
		
_atoi_return
		POP		{R1-R12, LR}
		BX		LR
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; long atol(string str)	 <- 32 bits
	; R0 = str
	; R1 = current result
	; R2 = sign
	; R3 = current char
	; R4 = temp digit
	
		EXPORT	_atol
_atol
		PUSH	{R1-R12, LR}
		
		; set starting values
		MOV		R1, #0
		MOV		R2, #0						; starting positive
		MOV		R5, #10						; save #10 to be used later

_atol_skip_white_spaces
		LDRB	R3, [R0], #1
		CMP		R3, #' '					; comparing with value of a white space
		BEQ		_atol_skip_white_spaces		; keep skipping values until no more white spaces
		SUB		R0, R0, #1					; step back after non-white space
		
_atol_check_sign
		LDRB	R3, [R0], #1
		CMP		R3, #'-'					; compare with value of negative sign
		BNE		_atol_loop
		MOV		R2, #1						; set negative
		
_atol_loop
		LDRB	R3, [R0], #1				; load next digit
		SUB		R4, R3, #'0'
		CMP		R4, #9
		BHI		_atol_done
		
		; add each digit to result
		MUL		R1, R1, R5					; shift digits left to make room for new digit
		ADD		R1, R1, R4					; add new digit
		B		_atol_loop

_atol_done
		CMP		R2, #0						; check sign
		MOVEQ	R0, R1						; positive result
		RSBSNE	R0, R1, #0					; negative result
		
_atol_return
		POP		{R1-R12, LR}
		BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; long long atoll(string str)  <- 64 bits
	; R0 = str
	; R1 & R2 = current result
	; R3 = current char
	; R4 = temp digit
	; R5 = sign
	
		EXPORT	_atoll
_atoll
		PUSH	{R2-R12, LR}
		
		; set starting values
		MOV		R1, #0						; result low
		MOV		R2, #0						; result high
		MOV		R5, #0						; starting positive
		MOV		R6, #10						; save #10 to be used later

_atoll_skip_white_spaces
		LDRB	R3, [R0], #1
		CMP		R3, #' '					; comparing with value of a white space
		BEQ		_atoll_skip_white_spaces		; keep skipping values until no more white spaces
		SUB		R0, R0, #1					; step back after non-white space
		
_atoll_check_sign
		LDRB	R3, [R0], #1
		CMP		R3, #'-'					; compare with value of negative sign
		BNE		_atoll_loop
		MOV		R5, #1						; set negative
		
_atoll_loop
		LDRB	R3, [R0], #1				; load next digit
		SUB		R4, R3, #'0'
		CMP		R4, #9
		BHI		_atoll_done
		
		; 64-bit multiplication: result = result * 10 + digit
		UMULL	R7, R8, R1, R6				; R8:R7 = R1 * 10
		MLA		R8, R2, R6, R8				; R8 += R2 * 10
		; add digit to lower register
		ADDS	R1, R7, R4					; R1 = R7 + digit
		ADC		R2, R8, #0					; R2 = R8 + carry
		B		_atoll_loop

_atoll_done
		CMP		R5, #0						; check sign
		BEQ		_atoll_return
		
		; negate 64-bit result
		RSBS	R1, R1, #0				; R1 = -R1
		SBC		R2, R2, #0					; R2 = -R2 - carry
		
_atoll_return
		; first shift return values into correct registers
		MOV		R0, R1
		MOV		R1, R2
		POP		{R2-R12, LR}
		BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* memcpy(void* dest, const void* src, size_t size)
	; R0 = destination
	; R1 = source
	; R2 = size
	
		EXPORT _memcpy
_memcpy
		PUSH	{R1-R12, LR}
		
		MOV		R3, #0						; counter
		MOV		R4, R0						; maintain original destination location

_memcpy_loop
		; loads and stores byte by byte
		CMP		R3, R2
		BEQ		_memcpy_return
		LDRB	R5, [R1], #1
		STRB	R5, [R4], #1
		ADD		R3, R3, #1					; increment counter
		B		_memcpy_loop
				
_memcpy_return		
		POP		{R1-R12, LR}
		BX 		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* memmove(void* dest, const void* src, size_t size)
	; R0 = destination
	; R1 = source
	; R2 = size

		EXPORT _memmove
_memmove
		PUSH	{R1-R12, LR}
		
		MOV		R3, #0						; counter
		MOV		R4, R0						; maintain original destination location by using R4
		
		; check for overlap in locations
		ADD		R5, R1, R2					; source + size
		CMP		R5, R4
		BLS		_memmove_forward_loop
		
		; add size to both source and destination
		ADD		R4, R4, R2
		ADD		R1, R1, R2
		
_memmove_backward_loop
		; load and store values backwards to avoid overlap
		CMP		R3, R2
		BEQ		_memmove_return
		
		LDRB	R6, [R1], #-1
		STRB	R6, [R4], #-1
		ADD		R3, R3, #1					; increment counter
		B		_memmove_backward_loop

_memmove_forward_loop
		; loads and stores forwards byte by byte
		CMP		R3, R2
		BEQ		_memmove_return
		LDRB	R6, [R1], #1
		STRB	R6, [R4], #1
		ADD		R3, R3, #1					; increment counter
		B		_memmove_forward_loop
				
_memmove_return		
		POP		{R1-R12, LR}
		BX 		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		END			
