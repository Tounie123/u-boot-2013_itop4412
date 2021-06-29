/*
 * Lowlevel setup for ORIGEN board based on EXYNOS4210
 *
 * Copyright (C) 2011 Samsung Electronics
 *
 * See file CREDITS for list of people who contributed to this
 * project.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

#include <config.h>
#include <version.h>
#include <asm/arch/cpu.h>
#include "origen_setup.h"
/*
 * Register usages:
 *
 * r5 has zero always
 * r7 has GPIO part1 base 0x11400000
 * r6 has GPIO part2 base 0x11000000
 */

#define MEM_DLLl_ON

wait_mux_state:
    ldr r1, [r0, r2]
    cmp r1, r3
    bne wait_mux_state
    mov pc, lr

wait_pll_lock:
    ldr r1, [r0, r2]
    tst r1, #(1<<29)
    beq wait_pll_lock
    mov pc, lr

wait_phy_state:
    //ldr r1, [r0, #DMC_PHYSTATUS]
    ldr r1, [r0, #64]
    tst r1, #(1<<2)
    beq wait_phy_state
    mov pc, lr

_TEXT_BASE:
	.word	CONFIG_SYS_TEXT_BASE

	.globl lowlevel_init
lowlevel_init:
    /* use iROM stack in bl2 */
    ldr sp, =0x02060000
	push	{lr}

	/* r5 has always zero */
	mov	r5, #0
	ldr	r7, =EXYNOS4_GPIO_PART1_BASE
	ldr	r6, =EXYNOS4_GPIO_PART2_BASE

	/* check reset status */
	ldr	r0, =(EXYNOS4_POWER_BASE + INFORM1_OFFSET)
	ldr	r1, [r0]

	/* AFTR wakeup reset */
	ldr	r2, =S5P_CHECK_DIDLE
	cmp	r1, r2
	beq	exit_wakeup

	/* LPA wakeup reset */
	ldr	r2, =S5P_CHECK_LPA
	cmp	r1, r2
	beq	exit_wakeup

	/* Sleep wakeup reset */
	ldr	r2, =S5P_CHECK_SLEEP
	cmp	r1, r2
	beq	wakeup_reset

	/*
	 * If U-boot is already running in ram, no need to relocate U-Boot.
	 * Memory controller must be configured before relocating U-Boot
	 * in ram.
	 */
	//ldr	r0, =0x0ffffff		/* r0 <- Mask Bits*/
	ldr	r0, =0xff000fff		/* r0 <- Mask Bits*/
	bic	r1, pc, r0		/* pc <- current addr of code */
					/* r1 <- unmasked bits of pc */
	ldr	r2, _TEXT_BASE		/* r2 <- original base addr in ram */
	bic	r2, r2, r0		/* r2 <- unmasked bits of r2*/
	cmp	r1, r2			/* compare r1, r2 */
	beq	1f			/* r0 == r1 then skip sdram init */

	/* init system clock */
	bl system_clock_init

	/* Memory initialize */
	bl mem_ctrl_asm_init

1:

	/* for UART */
	bl uart_asm_init
	bl tzpc_init
	pop	{pc}

wakeup_reset:
	bl system_clock_init
	bl mem_ctrl_asm_init
	bl tzpc_init

exit_wakeup:
	/* Load return address and jump to kernel */
	ldr	r0, =(EXYNOS4_POWER_BASE + INFORM0_OFFSET)

	/* r1 = physical address of exynos4210_cpu_resume function */
	ldr	r1, [r0]

	/* Jump to kernel*/
	mov	pc, r1
	nop
	nop

/*
 * system_clock_init: Initialize core clock and bus clock.
 * void system_clock_init(void)
 */
system_clock_init:
	push	{lr}
	ldr	r0, =EXYNOS4_CLOCK_BASE

#if 1
@ CMU_CPU MUX / DIV
    ldr r1, =0x0
    ldr r2, =CLK_SRC_CPU_OFFSET
    str r1, [r0, r2]

    //ldr r2, =CLK_MUX_STAT_CPU_OFFSET
    ldr r2, =0x14400
    ldr r3, =0x01110001
    bl wait_mux_state

    ldr r1, =CLK_DIV_DMC0_VAL
    ldr r2, =CLK_DIV_DMC0_OFFSET
    str r1, [r0, r2]
    ldr r1, =CLK_DIV_DMC1_VAL
    ldr r2, =CLK_DIV_DMC1_OFFSET
    str r1, [r0, r2]

@ CMU_TOP MUX / DIV
    ldr r1, =0x0
    ldr r2, =CLK_SRC_TOP0_OFFSET
    str r1, [r0, r2]

    //ldr r2, =CLK_MUX_STAT_TOP_OFFSET
    ldr r2, =0x0C410
    ldr r3, =0x11111111
    bl wait_mux_state

    ldr r1, =0x0
    ldr r2, =CLK_SRC_TOP1_OFFSET
    str r1, [r0, r2]

    //ldr r2, =CLK_MUX_STAT_TOP1_OFFSET
    ldr r2, =0x0C414
    ldr r3, =0x01111110
    bl wait_mux_state

    ldr r1, =CLK_DIV_TOP_VAL
    ldr r2, =CLK_DIV_TOP_OFFSET
    str r1, [r0, r2]

@ CMU_LEFTBUS MUX / DIV
    ldr r1, =0x10
    ldr r2, =CLK_SRC_LEFTBUS_OFFSET
    str r1, [r0, r2]

    //ldr r2, =CLK_MUX_STAT_LEFTBUS_OFFSET
    ldr r2, =0x04400
    ldr r3, =0x00000021
    bl wait_mux_state

    ldr r1, =CLK_DIV_LEFTBUS_VAL
    ldr r2, =CLK_DIV_LEFTBUS_OFFSET
    str r1, [r0, r2]

@ CMU_RIGHTBUS MUX / DIV
    ldr r1, =0x10
    ldr r2, =CLK_SRC_RIGHTBUS_OFFSET
    str r1, [r0, r2]

    //ldr r2, =CLK_MUX_STAT_RIGHTBUS_OFFSET
    ldr r2, =0x08400
    ldr r3, =0x00000021
    bl wait_mux_state

    ldr r1, =CLK_DIV_RIGHTBUS_VAL
    ldr r2, =CLK_DIV_RIGHTBUS_OFFSET
    str r1, [r0, r2]

@ Set PLL locktime
    //ldr r1, =APLL_LOCK_VAL
    ldr r1, =0x1C20
    ldr r2, =APLL_LOCK_OFFSET
    str r1, [r0, r2]

    //ldr r1, =MPLL_LOCK_VAL
    ldr r1, =0x1C20
    ldr r2, =MPLL_LOCK_OFFSET
    str r1, [r0, r2]

    //ldr r1, =EPLL_LOCK_VAL
    ldr r1, =0x1C20
    ldr r2, =EPLL_LOCK_OFFSET
    str r1, [r0, r2]

    //ldr r1, =VPLL_LOCK_VAL
    ldr r1, =0x1C20
    ldr r2, =VPLL_LOCK_OFFSET
    str r1, [r0, r2]

    ldr r1, =CLK_DIV_CPU0_VAL
    ldr r2, =CLK_DIV_CPU0_OFFSET
    str r1, [r0, r2]

    ldr r1, =CLK_DIV_CPU1_VAL
    ldr r2, =CLK_DIV_CPU1_OFFSET
    str r1, [r0, r2]

@ Set APLL
    ldr r1, =APLL_CON1_VAL
    ldr r2, =APLL_CON1_OFFSET
    str r1, [r0, r2]

    ldr r1, =APLL_CON0_VAL
    ldr r2, =APLL_CON0_OFFSET
    str r1, [r0, r2]

    /* check MPLL and if MPLL is not 400 Mhz skip MPLL resetting for C2C operation */
    ldr r2, =MPLL_CON0_OFFSET
    ldr r1, [r0, r2]
    ldr r3, =0xA0640301
    cmp r1, r3
    bne skip_mpll

@ Set MPLL
    ldr r1, =MPLL_CON1_VAL
    ldr r2, =MPLL_CON1_OFFSET
    str r1, [r0, r2]

    ldr r1, =MPLL_CON0_VAL
    ldr r2, =MPLL_CON0_OFFSET
    str r1, [r0, r2]

skip_mpll:
@ Set EPLL
    //ldr     r1, =EPLL_CON2_VAL
    ldr     r1, =0x80
    //ldr     r2, =EPLL_CON2_OFFSET
    ldr     r2, =0x0C118
    str     r1, [r0, r2]

    ldr     r1, =EPLL_CON1_VAL
    ldr     r2, =EPLL_CON1_OFFSET
    str     r1, [r0, r2]

    ldr     r1, =EPLL_CON0_VAL
    ldr     r2, =EPLL_CON0_OFFSET
    str     r1, [r0, r2]

@ Set VPLL
    //ldr     r1, =VPLL_CON2_VAL
    ldr     r1, =0x80
    //ldr     r2, =VPLL_CON2_OFFSET
    ldr     r2, =0x0C128
    str     r1, [r0, r2]

    ldr     r1, =VPLL_CON1_VAL
    ldr     r2, =VPLL_CON1_OFFSET
    str     r1, [r0, r2]

    ldr     r1, =VPLL_CON0_VAL
    ldr     r2, =VPLL_CON0_OFFSET
    str     r1, [r0, r2]

    ldr r2, =APLL_CON0_OFFSET
    bl wait_pll_lock
    ldr r2, =MPLL_CON0_OFFSET
    bl wait_pll_lock
    ldr r2, =EPLL_CON0_OFFSET
    bl wait_pll_lock
    ldr r2, =VPLL_CON0_OFFSET
    bl wait_pll_lock

    #if 1
    // 点亮LED3
    ldr r0, =0x11000060
    mov r1, #(0x01 << 4)
    str r1, [r0]

    ldr r0, =0x11000064
    mov r1, #0x2
    str r1, [r0]
    #endif

    ldr r1, =0x01000001
    ldr r2, =CLK_SRC_CPU_OFFSET
    str r1, [r0, r2]

    //ldr r2, =CLK_MUX_STAT_CPU_OFFSET
    ldr r2, =0x14400
    ldr r3, =0x02110002
    bl wait_mux_state

    ldr r1, =0x00011000
    ldr r2, =CLK_SRC_DMC_OFFSET
    str r1, [r0, r2]

    //ldr r2, =CLK_MUX_STAT_DMC_OFFSET
    ldr r2, =0x10400
    ldr r3, =0x11102111
    bl wait_mux_state

    ldr r1, =0x00000110
    ldr r2, =CLK_SRC_TOP0_OFFSET
    str r1, [r0, r2]

    //ldr r2, =CLK_MUX_STAT_TOP_OFFSET
    ldr r2, =0x0C410
    ldr r3, =0x11111221
    bl wait_mux_state

    /* skip MUX_ACLK_200_SUB_SEL, MUX_ACLK_400_MCUISP_SUB_SEL setting for CMU_SYSCLK_ISP function */
    ldr r1, =0x00011000
    ldr r2, =CLK_SRC_TOP1_OFFSET
    str r1, [r0, r2]

    // can not light led
    //ldr r2, =CLK_MUX_STAT_TOP1_OFFSET
    ldr r2, =0x0C414
    ldr r3, =0x01122110
    bl wait_mux_state

    //ldr r0, =CHIP_ID_BASE
    ldr r0, =0x10000000
    ldr r1, [r0]
    lsr r1, r1, #8
    and r1, r1, #3
    cmp r1, #2
    bne v310_2

    /* check C2C_CTRL enable bit */
    //ldr r3, =S5PV310_POWER_BASE
    ldr r3, =0x10020000
    //ldr r1, [r3, #C2C_CTRL_OFFSET]
    ldr r1, [r3, #36]
    and r1, r1, #1
    cmp r1, #0
    bne v310_2

    #if 0
    // 点亮LED3
    ldr r0, =0x11000060
    mov r1, #(0x01 << 4)
    str r1, [r0]

    ldr r0, =0x11000064
    mov r1, #0x2
    str r1, [r0]
    #endif

@ ConControl
#ifdef MEM_DLLl_ON
	//ldr	r0, =APB_DMC_0_BASE
	ldr	r0, =0x10600000

	ldr	r1, =0x7F10100A
	ldr	r2, =DMC_PHYCONTROL0
	str	r1, [r0, r2]

	ldr	r1, =0xE0000084
	ldr	r2, =DMC_PHYCONTROL1
	str	r1, [r0, r2]

	ldr	r1, =0x7F10100B
	ldr	r2, =DMC_PHYCONTROL0
	str	r1, [r0, r2]

	bl wait_phy_state

	ldr	r1, =0x0000008C
	ldr	r2, =DMC_PHYCONTROL1
	str	r1, [r0, r2]
	ldr	r1, =0x00000084
	ldr	r2, =DMC_PHYCONTROL1
	str	r1, [r0, r2]

	bl wait_phy_state

	//ldr	r0, =APB_DMC_1_BASE
	ldr	r0, =0x10610000

	ldr	r1, =0x7F10100A
	ldr	r2, =DMC_PHYCONTROL0
	str	r1, [r0, r2]

	ldr	r1, =0xE0000084
	ldr	r2, =DMC_PHYCONTROL1
	str	r1, [r0, r2]

	ldr	r1, =0x7F10100B
	ldr	r2, =DMC_PHYCONTROL0
	str	r1, [r0, r2]

	bl wait_phy_state

	ldr	r1, =0x0000008C
	ldr	r2, =DMC_PHYCONTROL1
	str	r1, [r0, r2]
	ldr	r1, =0x00000084
	ldr	r2, =DMC_PHYCONTROL1
	str	r1, [r0, r2]

	bl wait_phy_state
#endif

	//ldr	r0, =APB_DMC_0_BASE
	ldr	r0, =0x10600000
	ldr	r1, =0x0FFF30FA
	ldr	r2, =DMC_CONCONTROL
	str	r1, [r0, r2]

	//ldr	r0, =APB_DMC_1_BASE
	ldr	r0, =0x10610000
	ldr	r1, =0x0FFF30FA
	ldr	r2, =DMC_CONCONTROL
	str	r1, [r0, r2]

	//ldr	r0, =APB_DMC_0_BASE
	ldr	r0, =0x10600000
	ldr	r1, =0x00202533
	ldr	r2, =DMC_MEMCONTROL
	str	r1, [r0, r2]

	//ldr	r0, =APB_DMC_1_BASE
	ldr	r0, =0x10610000
	ldr	r1, =0x00202533
	ldr	r2, =DMC_MEMCONTROL
	str	r1, [r0, r2]

v310_2:
	pop	{pc}

#else
	/* APLL(1), MPLL(1), CORE(0), HPM(0) */
	ldr	r1, =CLK_SRC_CPU_VAL
	ldr	r2, =CLK_SRC_CPU_OFFSET
	str	r1, [r0, r2]

	/* wait ?us */
	mov	r1, #0x10000
2:	subs	r1, r1, #1
	bne	2b

	ldr	r1, =CLK_SRC_TOP0_VAL
	ldr	r2, =CLK_SRC_TOP0_OFFSET
	str	r1, [r0, r2]

	ldr	r1, =CLK_SRC_TOP1_VAL
	ldr	r2, =CLK_SRC_TOP1_OFFSET
	str	r1, [r0, r2]

	/* DMC */
	ldr	r1, =CLK_SRC_DMC_VAL
	ldr	r2, =CLK_SRC_DMC_OFFSET
	str	r1, [r0, r2]

	/*CLK_SRC_LEFTBUS */
	ldr	r1, =CLK_SRC_LEFTBUS_VAL
	ldr	r2, =CLK_SRC_LEFTBUS_OFFSET
	str	r1, [r0, r2]

	/*CLK_SRC_RIGHTBUS */
	ldr	r1, =CLK_SRC_RIGHTBUS_VAL
	ldr	r2, =CLK_SRC_RIGHTBUS_OFFSET
	str	r1, [r0, r2]

	/* SATA: SCLKMPLL(0), MMC[0:4]: SCLKMPLL(6) */
	ldr	r1, =CLK_SRC_FSYS_VAL
	ldr	r2, =CLK_SRC_FSYS_OFFSET
	str	r1, [r0, r2]

	/* UART[0:4] */
	ldr	r1, =CLK_SRC_PERIL0_VAL
	ldr	r2, =CLK_SRC_PERIL0_OFFSET
	str	r1, [r0, r2]

	/* CAM , FIMC 0-3 */
	ldr	r1, =CLK_SRC_CAM_VAL
	ldr	r2, =CLK_SRC_CAM_OFFSET
	str	r1, [r0, r2]

	/* MFC */
	ldr	r1, =CLK_SRC_MFC_VAL
	ldr	r2, =CLK_SRC_MFC_OFFSET
	str	r1, [r0, r2]

	/* G3D */
	ldr	r1, =CLK_SRC_G3D_VAL
	ldr	r2, =CLK_SRC_G3D_OFFSET
	str	r1, [r0, r2]

	/* LCD0 */
	ldr	r1, =CLK_SRC_LCD0_VAL
	ldr	r2, =CLK_SRC_LCD0_OFFSET
	str	r1, [r0, r2]

	/* wait ?us */
	mov	r1, #0x10000
3:	subs	r1, r1, #1
	bne	3b

	/* CLK_DIV_CPU0 */
	ldr	r1, =CLK_DIV_CPU0_VAL
	ldr	r2, =CLK_DIV_CPU0_OFFSET
	str	r1, [r0, r2]

	/* CLK_DIV_CPU1 */
	ldr	r1, =CLK_DIV_CPU1_VAL
	ldr	r2, =CLK_DIV_CPU1_OFFSET
	str	r1, [r0, r2]

	/* CLK_DIV_DMC0 */
	ldr	r1, =CLK_DIV_DMC0_VAL
	ldr	r2, =CLK_DIV_DMC0_OFFSET
	str	r1, [r0, r2]

	/*CLK_DIV_DMC1 */
	ldr	r1, =CLK_DIV_DMC1_VAL
	ldr	r2, =CLK_DIV_DMC1_OFFSET
	str	r1, [r0, r2]

	/* CLK_DIV_LEFTBUS */
	ldr	r1, =CLK_DIV_LEFTBUS_VAL
	ldr	r2, =CLK_DIV_LEFTBUS_OFFSET
	str	r1, [r0, r2]

	/* CLK_DIV_RIGHTBUS */
	ldr	r1, =CLK_DIV_RIGHTBUS_VAL
	ldr	r2, =CLK_DIV_RIGHTBUS_OFFSET
	str	r1, [r0, r2]

	/* CLK_DIV_TOP */
	ldr	r1, =CLK_DIV_TOP_VAL
	ldr	r2, =CLK_DIV_TOP_OFFSET
	str	r1, [r0, r2]

	/* MMC[0:1] */
	ldr	r1, =CLK_DIV_FSYS1_VAL		/* 800(MPLL) / (15 + 1) */
	ldr	r2, =CLK_DIV_FSYS1_OFFSET
	str	r1, [r0, r2]

	/* MMC[2:3] */
	ldr	r1, =CLK_DIV_FSYS2_VAL		/* 800(MPLL) / (15 + 1) */
	ldr	r2, =CLK_DIV_FSYS2_OFFSET
	str	r1, [r0, r2]

	/* MMC4 */
	ldr	r1, =CLK_DIV_FSYS3_VAL		/* 800(MPLL) / (15 + 1) */
	ldr	r2, =CLK_DIV_FSYS3_OFFSET
	str	r1, [r0, r2]

	/* CLK_DIV_PERIL0: UART Clock Divisors */
	ldr	r1, =CLK_DIV_PERIL0_VAL
	ldr	r2, =CLK_DIV_PERIL0_OFFSET
	str	r1, [r0, r2]

	/* CAM, FIMC 0-3: CAM Clock Divisors */
	ldr	r1, =CLK_DIV_CAM_VAL
	ldr	r2, =CLK_DIV_CAM_OFFSET
	str	r1, [r0, r2]

	/* CLK_DIV_MFC: MFC Clock Divisors */
	ldr	r1, =CLK_DIV_MFC_VAL
	ldr	r2, =CLK_DIV_MFC_OFFSET
	str	r1, [r0, r2]

	/* CLK_DIV_G3D: G3D Clock Divisors */
	ldr	r1, =CLK_DIV_G3D_VAL
	ldr	r2, =CLK_DIV_G3D_OFFSET
	str	r1, [r0, r2]

	/* CLK_DIV_LCD0: LCD0 Clock Divisors */
	ldr	r1, =CLK_DIV_LCD0_VAL
	ldr	r2, =CLK_DIV_LCD0_OFFSET
	str	r1, [r0, r2]

	/* Set PLL locktime */
	ldr	r1, =PLL_LOCKTIME
	ldr	r2, =APLL_LOCK_OFFSET
	str	r1, [r0, r2]

	ldr	r1, =PLL_LOCKTIME
	ldr	r2, =MPLL_LOCK_OFFSET
	str	r1, [r0, r2]

	ldr	r1, =PLL_LOCKTIME
	ldr	r2, =EPLL_LOCK_OFFSET
	str	r1, [r0, r2]

	ldr	r1, =PLL_LOCKTIME
	ldr	r2, =VPLL_LOCK_OFFSET
	str	r1, [r0, r2]

	/* APLL_CON1 */
	ldr	r1, =APLL_CON1_VAL
	ldr	r2, =APLL_CON1_OFFSET
	str	r1, [r0, r2]

	/* APLL_CON0 */
	ldr	r1, =APLL_CON0_VAL
	ldr	r2, =APLL_CON0_OFFSET
	str	r1, [r0, r2]

	/* MPLL_CON1 */
	ldr	r1, =MPLL_CON1_VAL
	ldr	r2, =MPLL_CON1_OFFSET
	str	r1, [r0, r2]

	/* MPLL_CON0 */
	ldr	r1, =MPLL_CON0_VAL
	ldr	r2, =MPLL_CON0_OFFSET
	str	r1, [r0, r2]

	/* EPLL */
	ldr	r1, =EPLL_CON1_VAL
	ldr	r2, =EPLL_CON1_OFFSET
	str	r1, [r0, r2]

	/* EPLL_CON0 */
	ldr	r1, =EPLL_CON0_VAL
	ldr	r2, =EPLL_CON0_OFFSET
	str	r1, [r0, r2]

	/* VPLL_CON1 */
	ldr	r1, =VPLL_CON1_VAL
	ldr	r2, =VPLL_CON1_OFFSET
	str	r1, [r0, r2]

	/* VPLL_CON0 */
	ldr	r1, =VPLL_CON0_VAL
	ldr	r2, =VPLL_CON0_OFFSET
	str	r1, [r0, r2]

	/* wait ?us */
	mov	r1, #0x30000
4:	subs	r1, r1, #1
	bne	4b

	pop	{pc}
#endif

/*
 * uart_asm_init: Initialize UART in asm mode, 115200bps fixed.
 * void uart_asm_init(void)
 */
	.globl uart_asm_init
uart_asm_init:

    #if 1
	/* set GPIO to enable UART */
	@ GPIO setting for UART for UART0/1
	ldr	r0, =0x11400000
	ldr	r1, =0x22222222
	str   	r1, [r0]
	ldr	r0, =0x11400020
	ldr	r1, =0x222222
	str	r1, [r0]

	//ldr	r0, =CMU_BASE	@0x1003_0000
	ldr	r0, =0x10030000	@0x1003_0000
	ldr	r1, =CLK_SRC_PERIL0_VAL		@0x666666
	ldr	r2, =CLK_SRC_PERIL0_OFFSET
	str	r1, [r0, r2]
	ldr	r1, =CLK_DIV_PERIL0_VAL		@0x777777
	ldr	r2, =CLK_DIV_PERIL0_OFFSET
	str	r1, [r0, r2]

	//ldr	r0, =ELFIN_UART_CONSOLE_BASE		@0xEC000000
	ldr	r0, =0xEC000000		@0xEC000000
	ldr	r1, =0x111
	str	r1, [r0, #UFCON_OFFSET]

	mov	r1, #0x3
	str	r1, [r0, #ULCON_OFFSET]

	ldr	r1, =0x3c5
	str	r1, [r0, #UCON_OFFSET]

	//ldr	r1, =UART_UBRDIV_VAL	@0x2B /*  UDIV(43) = ((82,500,000 / 16 / 115200) - 1) */
	ldr	r1, =0x2B	@0x2B /*  UDIV(43) = ((82,500,000 / 16 / 115200) - 1) */
	str	r1, [r0, #UBRDIV_OFFSET]

	//ldr	r1, =UART_UDIVSLOT_VAL	@0xC /* UFRACVAL(12) = ((((82,500,000 / 16 / 115200) - 1) - 43) * 16) */
	ldr	r1, =0xC	@0xC /* UFRACVAL(12) = ((((82,500,000 / 16 / 115200) - 1) - 43) * 16) */
	//str	r1, [r0, #UDIVSLOT_OFFSET]
	str	r1, [r0, #0x2C]

	ldr	r1, =0x4f4f4f4f
	//str	r1, [r0, #UTXH_OFFSET]		@'O'
	str	r1, [r0, #0x20]		@'O'

	mov	pc, lr

    #else
	/* setup UART0-UART3 GPIOs (part1) */
	mov	r0, r7
	ldr	r1, =EXYNOS4_GPIO_A0_CON_VAL
	str	r1, [r0, #EXYNOS4_GPIO_A0_CON_OFFSET]
	ldr	r1, =EXYNOS4_GPIO_A1_CON_VAL
	str	r1, [r0, #EXYNOS4_GPIO_A1_CON_OFFSET]

	ldr r0, =EXYNOS4_UART_BASE
	add r0, r0, #EXYNOS4_DEFAULT_UART_OFFSET

	ldr	r1, =ULCON_VAL
	str	r1, [r0, #ULCON_OFFSET]
	ldr	r1, =UCON_VAL
	str	r1, [r0, #UCON_OFFSET]
	ldr	r1, =UFCON_VAL
	str	r1, [r0, #UFCON_OFFSET]
	ldr	r1, =UBRDIV_VAL
	str	r1, [r0, #UBRDIV_OFFSET]
	ldr	r1, =UFRACVAL_VAL
	str	r1, [r0, #UFRACVAL_OFFSET]
	mov	pc, lr
	nop
	nop
	nop
    #endif

/* Setting TZPC[TrustZone Protection Controller] */
tzpc_init:
	ldr	r0, =TZPC0_BASE
	mov	r1, #R0SIZE
	str	r1, [r0]
	mov	r1, #DECPROTXSET
	str	r1, [r0, #TZPC_DECPROT0SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT1SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT2SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT3SET_OFFSET]

	ldr	r0, =TZPC1_BASE
	str	r1, [r0, #TZPC_DECPROT0SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT1SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT2SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT3SET_OFFSET]

	ldr	r0, =TZPC2_BASE
	str	r1, [r0, #TZPC_DECPROT0SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT1SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT2SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT3SET_OFFSET]

	ldr	r0, =TZPC3_BASE
	str	r1, [r0, #TZPC_DECPROT0SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT1SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT2SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT3SET_OFFSET]

	ldr	r0, =TZPC4_BASE
	str	r1, [r0, #TZPC_DECPROT0SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT1SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT2SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT3SET_OFFSET]

	ldr	r0, =TZPC5_BASE
	str	r1, [r0, #TZPC_DECPROT0SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT1SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT2SET_OFFSET]
	str	r1, [r0, #TZPC_DECPROT3SET_OFFSET]

	mov	pc, lr
