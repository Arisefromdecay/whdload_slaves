;*---------------------------------------------------------------------------
;  :Program.	BoppinHD.asm
;  :Contents.	Slave for "Boppin"
;  :Author.	JOTD, from Wepl sources
;  :Original	v1 
;  :Version.	$Id: BoppinHD.asm 1.2 2002/02/08 01:18:39 wepl Exp wepl $
;  :History.	%DATE% started
;  :Requires.	-
;  :Copyright.	Public Domain
;  :Language.	68000 Assembler
;  :Translator.	Devpac 3.14, Barfly 2.9
;  :To Do.
;---------------------------------------------------------------------------*

	INCDIR	Include:
	INCLUDE	whdload.i
	INCLUDE	whdmacros.i
	INCLUDE	lvo/dos.i

	IFD BARFLY
	OUTPUT	"Renegade.slave"
	IFND	CHIP_ONLY
	BOPT	O+				;enable optimizing
	BOPT	OG+				;enable optimizing
	ENDC
	BOPT	ODd-				;disable mul optimizing
	BOPT	ODe-				;disable mul optimizing
	BOPT	w4-				;disable 64k warnings
	BOPT	wo-			;disable optimizer warnings
	SUPER
	ENDC

;============================================================================


	IFD	CHIP_ONLY
HRTMON
CHIPMEMSIZE	= $200000
FASTMEMSIZE	= $0000
	ELSE
;;BLACKSCREEN
CHIPMEMSIZE	= $200000
FASTMEMSIZE	= $3000000
	ENDC

NUMDRIVES	= 1
WPDRIVES	= %0000

;DISKSONBOOT
DOSASSIGN
INITAGA
HDINIT
;IOCACHE		= 10000
;MEMFREE	= $200
;NEEDFPU
;SETPATCH
;STACKSIZE = 10000
BOOTDOS
; enabling cache in chipmem seems important for this game
; (c2p shit?). CACHE doesn't cut it...
CACHECHIPDATA

slv_Version	= 17
slv_Flags	= WHDLF_NoError|WHDLF_Examine|WHDLF_ClearMem|WHDLF_ReqAGA
slv_keyexit	= $5D	; num '*'

	include	whdload/kick31.s

    
;============================================================================

	IFD BARFLY
	DOSCMD	"WDate  >T:date"
	ENDC

DECL_VERSION:MACRO
	dc.b	"1.0"
	IFD BARFLY
		dc.b	" "
		INCBIN	"T:date"
	ENDC
	IFD	DATETIME
		dc.b	" "
		incbin	datetime
	ENDC
	ENDM
	dc.b	"$VER: slave "
	DECL_VERSION
	dc.b	0



slv_name		dc.b	"Mortal Kombat 3 (AGA)"
	IFD	CHIP_ONLY
	dc.b	" (DEBUG/CHIP MODE)"
	ENDC
			dc.b	0
slv_copy		dc.b	"2026 Arti",0
slv_info		dc.b	"adapted by JOTD",10,10
		dc.b	"Version "
		DECL_VERSION
		dc.b	0
slv_CurrentDir:
	dc.b	"data",0

env_dir:
	dc.b	"env",0
ram_dir:
	dc.b	"ram:",0
program_060:
	dc.b	"mk3-060",0
program_040:
	dc.b	"mk3-040",0
args		dc.b	10
args_end
	dc.b	0
slv_config
	dc.b	0

; version xx.slave works

	dc.b	"$","VER: slave "
	DECL_VERSION
	dc.b	0
	EVEN


_bootdos
		clr.l	$0.W

;        bsr _detect_controller_types
;        lea controller_joypad_0(pc),a0
;        clr.b   (a0)        ; no need to read port 0 extra buttons...
	; saves registers (needed for BCPL stuff, global vector, ...)

		lea	(_saveregs,pc),a0
		movem.l	d1-d7/a1-a2/a4-a6,(a0)
		lea	_stacksize(pc),a2
		move.l	4(a7),(a2)

		move.l	_resload(pc),a2		;A2 = resload
        lea	(tag,pc),a0
        jsr	(resload_Control,a2)

	
	;open doslib
		lea	(_dosname,pc),a1
		move.l	(4),a6
		jsr	(_LVOOldOpenLibrary,a6)
		move.l	d0,a6			;A6 = dosbase
        
		lea 	lowlevelname(pc),a0
		bsr		must_exist
		lea 	localename(pc),a0
		bsr		must_exist
		
		lea	env_dir(pc),a0
		lea		ram_dir(pc),a1
		bsr	_dos_assign
		
        IFD CHIP_ONLY
        movem.l a6,-(a7)
		move.l	$4.w,a6
        move.l  #$10000-$BA70,d0
        move.l  #MEMF_CHIP,d1
        jsr _LVOAllocMem(a6)
        movem.l (a7)+,a6
        ENDC

    ; store exe file size once and for all

		lea	program_040(pc),a0
		move.l	attnflags(pc),d0
		btst	#AFB_68060,d0
		beq		.1
		lea	program_060(pc),a0
		
.1:
		move.l	a0,-(a7)
		jsr		resload_GetFileSize(a2)
		lea	file_size(pc),a0
		move.l	d0,(a0)
		move.l	(a7)+,a0

	;load exe
		lea	args(pc),a1
		moveq	#args_end-args,d0
		lea	patch_main(pc),a5
		sub.l	a5,a5
		bsr	load_exe
	;quit
_quit		pea	TDREASON_OK
		move.l	(_resload,pc),a2
		jmp	(resload_Abort,a2)

; < A0 filename
; < A6 dosbase

must_exist:
	movem.l	d0-d1/a0-a1/a3,-(a7)
	move.l	a0,d1
	move.l	a0,a3
	move.l	#ACCESS_READ,d2
	jsr	_LVOLock(a6)
	move.l	d0,d1
	beq.b	.error
	jsr	_LVOUnLock(a6)
	movem.l	(a7)+,d0-d1/a0-a1/a3
	rts

.error
	jsr	(_LVOIoErr,a6)
	move.l	a3,-(a7)
	move.l	d0,-(a7)
	pea	TDREASON_DOSREAD
	move.l	(_resload,pc),-(a7)
	add.l	#resload_Abort,(a7)
	rts
	
patch_main:
	bsr		get_version
	add.w	d0,d0
	lea		pl_table(pc),a0
	add.w	(a0,d0.w),a0
	
    move.l  d7,a1
	jsr	resload_PatchSeg(a2)

    move.l  d7,a1
	add.l	a1,a1
	add.l	a1,a1
	rts

pl_table:
	dc.w	pl_version14-pl_table
	dc.w	pl_version15-pl_table
	

pl_version14:
    PL_START
	PL_L	$000434,$70004E71		; remove vbr access
	;PL_PS	$44ad2c,fix_access_fault_1
	;PL_PS	$44ac8e,fix_access_fault_1
	PL_END
pl_version15:
    PL_START
	PL_L	$00040c,$70004E71		; remove vbr access
	PL_END

fix_access_fault_1:
	lea	_custom,a6
	MOVE.W	#$4000,(154,A6)
    rts
	
get_version:
	movem.l	d1/a0/a1,-(a7)
	move.l	file_size(pc),d0

	cmp.l	#4573340,d0
	beq.b	.version1
	cmp.l	#4565532,d0
	beq.b	.version2
	
    
	pea	TDREASON_WRONGVER
	move.l	_resload(pc),-(a7)
	addq.l	#resload_Abort,(a7)
	rts

.version1
	moveq	#0,d0
	bra.b	.out
.version2
	moveq	#1,d0
	bra.b	.out
	nop

.out
	movem.l	(a7)+,d1/a0/a1
	rts


; < a0: program name
; < a1: arguments
; < d0: argument string length
; < a5: patch routine (0 if no patch routine)


load_exe:
	movem.l	d0-a6,-(a7)
	move.l	d0,d2
	move.l	a0,a3
	move.l	a1,a4
	move.l	a0,d1
	jsr	(_LVOLoadSeg,a6)

	move.l	d0,d7			;D7 = segment
	beq	.end			;file not found

	;patch here
	cmp.l	#0,A5
	beq.b	.skip
	movem.l	d2/d7/a4,-(a7)

	;get tags
    move.l  _resload(pc),a2
    lea (segments,pc),a0
    move.l  d7,(a0)
    lea	(tagseg,pc),a0
	jsr	(resload_Control,a2)


	jsr	(a5)
	bsr	_flushcache
	movem.l	(a7)+,d2/d7/a4
.skip
	;call
	move.l	d7,a3
	add.l	a3,a3
	add.l	a3,a3

	move.l	a4,a0

	movem.l	d7/a6,-(a7)

	move.l	d2,d0			; argument string length
	move.l	_stacksize(pc),-(a7)	; original stack format
	movem.l	(_saveregs,pc),d1-d7/a1-a2/a4-a6	; original registers (BCPL stuff)
	jsr	(4,a3)		; call program
	addq.l	#4,a7

	movem.l	(a7)+,d7/a6

	;remove exe

	move.l	d7,d1
	jsr	(_LVOUnLoadSeg,a6)

	movem.l	(a7)+,d0-a6
	rts

.end
	jsr	(_LVOIoErr,a6)
	move.l	a3,-(a7)
	move.l	d0,-(a7)
	pea	TDREASON_DOSREAD
	move.l	(_resload,pc),-(a7)
	add.l	#resload_Abort,(a7)
	rts

_saveregs
		ds.l	16,0
_stacksize
		dc.l	0
orig_vbl
    dc.l    0
	


file_size
	dc.l	0
	
tag
                dc.l    WHDLTAG_ATTNFLAGS_GET
attnflags:
                dc.l    0
		dc.l	WHDLTAG_CUSTOM2_GET
button_config	dc.l	0
    dc.l    0
tagseg
        dc.l    WHDLTAG_DBGSEG_SET
segments:
		dc.l	0
		dc.l	0
prev_joy1   dc.l    0

lowlevelname:
	dc.b	"libs/lowlevel.library",0
localename:
	dc.b	"libs/locale.library",0
;============================================================================

	END
