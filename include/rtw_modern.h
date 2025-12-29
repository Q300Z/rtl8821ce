#ifndef __RTW_MODERN_H__
#define __RTW_MODERN_H__

#define CONFIG_80211N_HT
#define CONFIG_80211AC_VHT
#define CONFIG_AP_MODE
#define CONFIG_NATIVEAP_MLME
#define CONFIG_P2P
#define CONFIG_PCI_HCI
#define RTL8821C_SUPPORT 1
#define RATE_ADAPTIVE_SUPPORT 0
#define RTW_DEF_MODULE_REGULATORY_CERT 0
#define DISABLE_BB_RF 0
/* Define other support macros to 0 to avoid -Wundef */
#define RTL8188E_SUPPORT 0
#define RTL8188F_SUPPORT 0
#define RTL8192E_SUPPORT 0
#define RTL8192F_SUPPORT 0
#define RTL8195A_SUPPORT 0
#define RTL8195B_SUPPORT 0
#define RTL8197F_SUPPORT 0
#define RTL8198F_SUPPORT 0
#define RTL8703B_SUPPORT 0
#define RTL8710B_SUPPORT 0
#define RTL8723B_SUPPORT 0
#define RTL8723D_SUPPORT 0
#define RTL8812A_SUPPORT 0
#define RTL8814A_SUPPORT 0
#define RTL8814B_SUPPORT 0
#define RTL8821A_SUPPORT 0
#define RTL8822B_SUPPORT 0
#define RTL8822C_SUPPORT 0
#define RTL8881A_SUPPORT 0
#define DBG 0
#define DRV_NAME "rtl8821ce"
#define ADPT_ARG(adapter) ((adapter)->pnetdev ? (adapter)->pnetdev->name : "NULL")
#define CONFIG_MLME_EXT
#define CONFIG_CONCURRENT_MODE
#define CONFIG_RTW_RA_TABLE
#define CONFIG_TDLS

#include <linux/version.h>
#include <linux/types.h>
#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/vmalloc.h>
#include <linux/skbuff.h>
#include <linux/netdevice.h>
#include <linux/ctype.h>
#include <linux/utsname.h>
#include <linux/random.h>
#include <linux/unaligned.h>
#include <linux/jiffies.h>
#include <linux/delay.h>
#include <linux/spinlock.h>
#include <linux/mutex.h>
#include <linux/semaphore.h>
#include <linux/timer.h>
#include <linux/interrupt.h>
#include <linux/workqueue.h>
#include <linux/atomic.h>
#include <linux/sched.h>
#include <linux/etherdevice.h>
#include <linux/wireless.h>
#include <net/iw_handler.h>
#include <net/cfg80211.h>
#include <linux/if_ether.h>
#include <linux/if_arp.h>
#include <linux/rtnetlink.h>

/* Types Fondamentaux */
#define VOID void
typedef void* PVOID;
typedef u32 NDIS_OID;
typedef u32 NDIS_STATUS;
typedef signed int sint;
typedef unsigned long systime;
typedef atomic_t ATOMIC_T;
typedef unsigned long _irqL;
typedef size_t SIZE_T;
typedef ssize_t SSIZE_T;
typedef uintptr_t SIZE_PTR;

#define IN
#define OUT

typedef struct sk_buff _pkt;
typedef struct sk_buff _buffer;
typedef struct net_device* _nic_hdl;

#define UCHAR  u8
#define USHORT u16
#define UINT   u32
#define ULONG  u32

typedef u8 u1Byte;
typedef u16 u2Byte;
typedef u32 u4Byte;
typedef u64 u8Byte;
typedef s8 s1Byte;
typedef s16 s2Byte;
typedef s32 s4Byte;
typedef s64 s8Byte;
typedef u8* pu1Byte;
typedef u16* pu2Byte;
typedef u32* pu4Byte;
typedef u64* pu8Byte;

typedef bool BOOLEAN;
typedef bool* PBOOLEAN;

#define _TRUE 1
#define _FALSE 0
#define _SUCCESS 1
#define _FAIL 0
#define SUCCESS 0
#define FAIL (-1)

#ifndef BIT0
#define BIT0 (0x1)
#define BIT1 (0x2)
#define BIT2 (0x4)
#define BIT3 (0x8)
#define BIT4 (0x10)
#define BIT5 (0x20)
#define BIT6 (0x40)
#define BIT7 (0x80)
#define BIT8 (0x100)
#define BIT9 (0x200)
#define BIT10 (0x400)
#define BIT11 (0x800)
#define BIT12 (0x1000)
#define BIT13 (0x2000)
#define BIT14 (0x4000)
#define BIT15 (0x8000)
#define BIT16 (0x10000)
#ifndef BIT
#define BIT(n) (1UL << (n))
#endif
#endif

/* Wrappers Sections Critiques */
#define _enter_critical(l, i)   spin_lock_irqsave(l, *(i))
#define _exit_critical(l, i)    spin_unlock_irqrestore(l, *(i))
#define _enter_critical_bh(l, i) spin_lock_bh(l)
#define _exit_critical_bh(l, i)  spin_unlock_bh(l)
#define _enter_critical_mutex(m, i) mutex_lock(m)
#define _exit_critical_mutex(m, i)  mutex_unlock(m)

/* Wrappers Listes/Queues */
#define _rtw_init_listhead(l)   INIT_LIST_HEAD((struct list_head *)(l))
#define rtw_list_insert_head(p, h) list_add((struct list_head *)(p), (struct list_head *)(h))
#define rtw_list_insert_tail(p, h) list_add_tail((struct list_head *)(p), (struct list_head *)(h))
#define rtw_is_list_empty(h)    list_empty((struct list_head *)(h))
#define rtw_list_delete(p)      list_del_init((struct list_head *)(p))
#define _rtw_init_queue(q)      do { INIT_LIST_HEAD(&((struct __queue *)(q))->queue); spin_lock_init(&((struct __queue *)(q))->lock); } while(0)
#define _rtw_queue_empty(q)     list_empty(&((struct __queue *)(q))->queue)
#define get_list_head(q)        (&((struct __queue *)(q))->queue)
#define rtw_end_of_queue_search(q, e) ((q) == (e))
#define get_next(l)             ((l)->next)
#define LIST_CONTAINOR(p, t, m) container_of(p, t, m)

/* Memory */
#define rtw_malloc(sz)          kmalloc(sz, GFP_ATOMIC)
#define rtw_zmalloc(sz)         kzalloc(sz, GFP_ATOMIC)
#define rtw_mfree(p, sz)        kfree(p)
#define _rtw_malloc(sz)         kmalloc(sz, GFP_ATOMIC)
#define _rtw_zmalloc(sz)        kzalloc(sz, GFP_ATOMIC)
#define _rtw_mfree(p, sz)       kfree(p)
#define _rtw_memcpy(d, s, l)    memcpy(d, s, l)
#define _rtw_memset(p, v, l)    memset(p, v, l)
#define _rtw_memcmp(a, b, l)    memcmp(a, b, l)
#define _rtw_memmove(d, s, l)   memmove(d, s, l)

#define LE_BITS_TO_1BYTE(p, offset, len) \
    (((*((u8 *)(p))) >> (offset)) & ((1UL << (len)) - 1))
#define LE_BITS_TO_2BYTE(p, offset, len) \
    (((get_unaligned_le16(p)) >> (offset)) & ((1UL << (len)) - 1))
#define LE_BITS_TO_4BYTE(p, offset, len) \
    (((get_unaligned_le32(p)) >> (offset)) & ((1UL << (len)) - 1))

#define _rtw_mutex_init(m)      mutex_init(m)
#define _rtw_mutex_free(m)      mutex_destroy(m)
#define _rtw_spinlock_free(l)   do {} while(0)
#define _rtw_spinlock(l)        spin_lock(l)
#define _rtw_spinunlock(l)      spin_unlock(l)
#define _rtw_init_sema(s, v)    sema_init(s, v)
#define _rtw_free_sema(s)       do {} while(0)
#define _rtw_down_sema(s)       (down_interruptible(s) ? _FAIL : _SUCCESS)
#define _rtw_up_sema(s)         up(s)

/* Helpers */
#define rtw_get_current_time()  jiffies
#define rtw_get_passing_time_ms(s) jiffies_to_msecs(jiffies - (s))
#define rtw_msleep_os(m)        msleep(m)
#define rtw_usleep_os(u)        usleep_range(u, (u) + 50)
#define rtw_ms_to_systime(m)    msecs_to_jiffies(m)
#define rtw_systime_to_ms(s)    jiffies_to_msecs(s)
#define ATOMIC_SET(v, i)        atomic_set(v, i)
#define ATOMIC_READ(v)          atomic_read(v)
#define ATOMIC_INC(v)           atomic_inc(v)
#define ATOMIC_INC_RETURN(v)    atomic_inc_return(v)
#define ATOMIC_DEC_RETURN(v)    atomic_dec_return(v)
#define utsname()               init_utsname()
#define rtw_random32()          get_random_u32()
#define RTW_GET_LE16(p)         get_unaligned_le16(p)
#define RTW_PUT_LE16(p, v)      put_unaligned_le16(v, p)
#define RTW_GET_BE16(p)         get_unaligned_be16(p)
#define RTW_GET_BE24(p)         ((u32)((p)[2]) | ((u32)((p)[1]) << 8) | ((u32)((p)[0]) << 16))
#define RTW_STATUS_CODE(e)      ((e) >= 0 ? _SUCCESS : _FAIL)
#define alpha_to_upper(c)       toupper(c)
#define rtw_warn_on(c)          WARN_ON(c)
#define rtw_min(a, b)           ((a) < (b) ? (a) : (b))
#define rtw_abs(x)              abs(x)

#define RTW_RX_HANDLED 2
#define rtw_os_pkt_free(s)      dev_kfree_skb(s)
#define rtw_os_pkt_data(s)      ((s)->data)
#define rtw_os_pkt_len(s)       ((s)->len)

/* Structs Aliases */
typedef struct semaphore _sema;
typedef spinlock_t _lock;
typedef struct mutex _mutex;

struct rtw_timer_list
{
    struct timer_list timer;
    void (*function)(void*);
    void* arg;
};

typedef struct rtw_timer_list _timer;

struct __queue
{
    struct list_head queue;
    _lock lock;
};

typedef struct __queue _queue;
typedef struct list_head _list;
typedef struct work_struct _workitem;
typedef void* _thread_hdl_;
typedef int thread_return;
typedef void* thread_context;

/* Configuration Limits */
#define CONFIG_IFACE_NUMBER 1
#define MACID_NUM_SW_LIMIT 128
#define SEC_CAM_ENT_NUM_SW_LIMIT 32

#define RND4(x) (((x) + 3) & ~3)

/* Prototypes */
u32 rtw_get_wait_hiq_empty_ms(void);
void _init_timer(void* ptimer, void* nic_hdl, void* pfunc, void* cntx);
#define rtw_init_timer(pt, nic, pf, ctx) _init_timer(pt, nic, pf, ctx)
#define _set_timer(pt, ms)      mod_timer(&((struct rtw_timer_list *)(pt))->timer, jiffies + msecs_to_jiffies(ms))
#define _cancel_timer_ex(pt)    del_timer_sync(&((struct rtw_timer_list *)(pt))->timer)

void flush_signals_thread(void);
void thread_enter(char* name);
void rtw_thread_stop(void* t);
void rtw_thread_wait_stop(void);
bool is_alpha(char c);

#ifndef PATH_LENGTH_MAX
#define PATH_LENGTH_MAX 512
#endif

#endif /* __RTW_MODERN_H__ */