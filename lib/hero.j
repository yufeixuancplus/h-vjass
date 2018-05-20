/* 
 * 单位组 
 */
globals
hHero hhero
hashtable hash_hero = null
integer HERO_SELECTION_TOKEN = 'o001'        //选英雄token
endglobals

struct hHero

    private static integer hk_drunkery = 1
    private static integer hk_drunkery_qty_now = 2
    private static integer hk_player_own_qty = 3
    private static integer hk_isout = 4
    private static integer hk_unit_type = 10000

	private static integer unit_qty = 0             //选择英雄数量
	private static integer drunkery_allow_qty = 11  //酒馆最大单位数量
	private static integer player_allow_qty = 1     //玩家最大单位数量
	private static real buildX = 0                  //选择英雄初始坐标X
    private static real buildY = 0                  //选择英雄初始坐标Y
    private static real buildDistance = 128.0       //酒馆/单位间距离
    private static real buildPerRow = 2             //每行多少个酒馆/单位
    private static group buildGroup = null          //建立单位组
    private static integer drunkeryID = 'n001'      //选英雄酒馆单位ID，默认是 n001
    private static real bornX = 250                 //生成英雄初始坐标X
    private static real bornY = 250                 //生成英雄初始坐标Y

    //设置单位被reset，使它可以被重新选择
    private static method unitReset takes integer unitId returns nothing
		call SaveBoolean( hash_hero , unitId , hk_isout,false )
	endmethod

    //设置单位已被选过，使它卖出
    private static method unitOut takes integer unitId returns nothing
		call SaveBoolean( hash_hero , unitId , hk_isout,true )
	endmethod

    private static method isOut takes integer unitId returns boolean
		return LoadBoolean( hash_hero , unitId , hk_isout )
	endmethod

    //设置生成选择位置XY
    public static method setBuildXY takes real x,real y returns nothing
        set buildX = x
        set buildY = y
    endmethod

    //设置生成选择位置的间隔距离
    public static method setBuildDistance takes real d returns nothing
        set buildDistance = d
    endmethod

    //设置生成单位的位置XY
    public static method setBornXY takes real x,real y returns nothing
        set bornX = x
        set bornY = y
    endmethod

    //保存单位
    //1.酒馆模式下，这些单位会在buildDrunkery时自动写进酒馆
    //1.双击模式下，这些单位会在buildDoubleClick时在地上排列单位
    //会增加 1 英雄种类数
    public static method push takes integer unitId returns nothing
        set unit_qty = unit_qty + 1
        call SaveInteger(hash_hero,0,hk_unit_type+unit_qty,unitId)
    endmethod

    //获取游戏单位种类数
    public static method getQty takes nothing returns integer
        return unit_qty
    endmethod

    //设置玩家最大单位数量,支持1～10
    public static method setPlayerAllowQty takes integer max returns nothing
        if(max>0 and max<=10)then
            set player_allow_qty = max
        else
            call hconsole.error("setPlayerMaxQty error")
        endif
	endmethod

    //获取玩家最大单位数量
    public static method getPlayerAllowQty takes nothing returns integer
        return player_allow_qty
    endmethod

    //设置玩家现有单位数量
    private static method setPlayerUnitQty takes player whichPlayer,integer now returns nothing
		call SaveInteger( hash_hero , GetHandleId(whichPlayer) , hk_player_own_qty , now )
	endmethod

    //获取玩家现有单位数量
    private static method getPlayerUnitQty takes player whichPlayer returns integer
		return LoadInteger( hash_hero , GetHandleId(whichPlayer) , hk_player_own_qty )
	endmethod

    //设置玩家现有单位
    private static method setPlayerUnit takes player whichPlayer,integer index,unit u returns nothing
		call SaveUnitHandle( hash_hero , GetHandleId(whichPlayer) , StringHash("hk_player_own_unit"+I2S(index)) , u )
	endmethod

    //获取玩家现有单位
    private static method getPlayerUnit takes player whichPlayer,integer index returns unit
		return LoadUnitHandle( hash_hero , GetHandleId(whichPlayer) , StringHash("hk_player_own_unit"+I2S(index)) )
	endmethod

    private static method getRandomUnitId takes nothing returns integer
        local integer max = getQty()
        local integer uid = 0
        local integer i = 0
        local integer qty = 0
        local integer array unitids
        if(max<=0)then
            return -1
        endif
        set i = max
        loop
            exitwhen i<=0
                set uid = LoadInteger(hash_hero,0,hk_unit_type+i)
                if(uid>0)then
                    if(isOut(uid) == false)then
                        set qty = qty+1
                        set unitids[qty] = uid
                    endif
                endif
            set i=i-1
        endloop
        if(qty>0)then
            return unitids[GetRandomInt(1,qty)]
        else
            return -1
        endif
    endmethod

    //剩10秒提示玩家快点选
    //同时关闭repick指令
    private static method tenSecTips takes nothing returns nothing
        local timer t = GetExpiredTimer()
        local trigger tgr_repick = htime.getTrigger(t,1)
        local real x = htime.getReal(t,2)
        local real y = htime.getReal(t,3)
        call htime.delTimer(t)
        call DisableTrigger( tgr_repick )
        call DestroyTrigger( tgr_repick )
        call hmsg.echo("还剩 10 秒，还未选择的玩家尽快啦～")
        call PingMinimapEx(x, y, 1.00, 254, 0, 0, true)
    endmethod

    //检查玩家是不是都选好了，将没有选单位的玩家T出游戏
    private static method checkPlayerChooseOver takes nothing returns nothing
        local integer i = player_max_qty
        loop
            exitwhen i<=0
                call hplayer.setStatus(players[i],hplayer.default_status_nil)
                call hplayer.defeat(players[i],"未选够游戏角色")
            set i = i-1
        endloop
    endmethod


    //todo -----------酒馆模式-----------

    /**
	 * 添加单位进酒馆
	 * 同时记录入库的店
	 * 这里单位指的是类型，所以是int
	 */
	private static method add2drunkery takes unit drunkery,integer unitId returns nothing
		call SaveUnitHandle( hash_hero , unitId , hk_drunkery , drunkery )
		call AddUnitToStock( drunkery,unitId , 1 , 1 )
	endmethod

    /**
	 * out单位自卖出的那个酒馆，random时候
	 * 这里单位指的是类型，所以是int
	 */
	private static method out2drunkery takes integer unitId returns nothing
		local unit drunkery = LoadUnitHandle( hash_hero , unitId , hk_drunkery )
        if(drunkery!=null)then
            call RemoveUnitFromStock( drunkery,unitId )
        endif
	endmethod

	/**
	 * 返回单位自卖出的那个酒馆，repick时候
	 * 这里单位指的是类型，所以是int
	 */
	private static method back2drunkery takes integer unitId returns nothing
		local unit drunkery = LoadUnitHandle( hash_hero , unitId , hk_drunkery )
        if(drunkery!=null)then
            call AddUnitToStock( drunkery,unitId , 1 , 1 )
        endif
	endmethod

    //设置酒馆现有单位数量
    private static method setDrunkeryQty takes unit drunkery,integer now returns nothing
		call SaveInteger( hash_hero , GetHandleId(drunkery) , hk_drunkery_qty_now , now )
	endmethod

    //获取酒馆现有单位数量
    private static method getDrunkeryQty takes unit drunkery returns integer
		return LoadInteger( hash_hero , GetHandleId(drunkery) , hk_drunkery_qty_now )
	endmethod

    //设置每个酒馆允许的最大单位数量，只允许1～11
    public static method setDrunkeryAllowQty takes integer qty returns nothing
        if(qty>0 and qty<=11)then
            set drunkery_allow_qty = qty
        else
            call hconsole.error("setAllowQty error")
        endif
    endmethod

    //设置每行生成酒馆最大，自动换行
    public static method setDrunkeryPerRow takes integer d returns nothing
        set buildPerRow = d
    endmethod

    //设置生成酒馆ID
    public static method setDrunkeryID takes integer id returns nothing
        set drunkeryID = id
    endmethod

    private static method buildDrunkerySellAction takes nothing returns nothing
        local unit u = GetSoldUnit()
        local player p = GetOwningPlayer(u)
        local integer qty = getPlayerUnitQty(p)
        local location loc = null
        local integer max = getPlayerAllowQty()
        local integer uid = GetUnitTypeId(u)
        if(qty>=max)then
            call hmsg.echoTo(p,"|cffffff80你已经选够单位|r",0)
            call back2drunkery(uid)
            call hunit.del(u,0)
            return
        endif
        set qty = qty+1
        call setPlayerUnit(p,qty,u)
        call setPlayerUnitQty(p,qty)
        call out2drunkery(uid)
        call unitOut(uid)
        set loc = Location(bornX,bornY)
        call SetUnitPositionLoc(u,loc)
        call RemoveLocation(loc)
        set loc = null
        if(qty>=max)then
            call hmsg.echoTo(p,"您选择了 "+"|cffffff80"+GetUnitName(u)+"|r,已挑选完毕",0)
        else 
            call hmsg.echoTo(p,"您选择了 "+"|cffffff80"+GetUnitName(u)+"|r,还差 "+I2S(max-qty)+" 个",0)
        endif
    endmethod

    private static method buildDrunkeryRandomAction takes nothing returns nothing
        local player p = GetTriggerPlayer()
        local integer max = getPlayerAllowQty()
        local integer qty = getPlayerUnitQty(p)
        local integer i = 0
        local integer uid = 0
        local unit u = null
        local string uname = ""
        if(qty>=max)then
            call hmsg.echoTo(p,"|cffffff80你已经选够单位|r",0)
            return
        endif
        set i = max
        loop
            exitwhen(i<=qty or uid==-1)
                set uid = getRandomUnitId()
                if(uid!=-1)then
                    call unitOut(uid)
                    call out2drunkery(uid)
                    set u = hunit.createUnitXY( p,uid,bornX,bornY )
                    set uname = uname+" "+GetUnitName(u)
                    call setPlayerUnit(p,i,u)
                endif
            set i = i-1
        endloop
        call setPlayerUnitQty(p,max)
        call hmsg.echoTo(p,"已为您 |cffffff80random|r 选择了 "+"|cffffff80"+I2S(max-qty)+"|r 个单位：|cffffff80"+uname+"|r",0)
    endmethod

    private static method buildDrunkeryRepickAction takes nothing returns nothing
        local player p = GetTriggerPlayer()
        local integer qty = getPlayerUnitQty(p)
        local integer i = 0
        local unit u = null
        local integer uid = 0
        if(qty<=0)then
            call hmsg.echoTo(p,"|cffffff80你还没有选过任何单位|r",0)
            return
        endif
        set i = qty
        loop
            exitwhen i<=0
                set u = getPlayerUnit(p,i)
                set uid = GetUnitTypeId(u)
                call back2drunkery(uid)
                call unitReset(uid)
                call setPlayerUnit(p,i,null)
                call hunit.del(u,0)
            set i = i-1
        endloop
        call setPlayerUnitQty(p,0)
        call hmsg.echoTo(p,"已为您 |cffffff80repick|r 了 "+"|cffffff80"+I2S(qty)+"|r 个单位",0)
    endmethod

    private static method buildDrunkeryClear takes nothing returns nothing
        local timer t = GetExpiredTimer()
        local trigger tgr_sell = htime.getTrigger(t,1)
        local trigger tgr_random = htime.getTrigger(t,2)
        call htime.delTimer(t)
        call DisableTrigger( tgr_sell )
        call DestroyTrigger( tgr_sell )
        call DisableTrigger( tgr_random )
        call DestroyTrigger( tgr_random )
        call checkPlayerChooseOver()
    endmethod

    //开始建立酒馆
    //同时开启random指令
    //同时开启repick指令
    public static method buildDrunkery takes real during returns nothing
        local integer i = getQty()
        local integer heroId = 0
        local unit u = null
        local unit hero = null
        local integer drunkeryNowQty = 0
        local integer totalRow = 1
        local integer rowNowQty = 0
        local trigger tgr_sell = null
        local trigger tgr_random = null
        local trigger tgr_repick = null
        local timer t = null
        local real x = 0
        local real y = buildY
        if(during<=20)then
            call hconsole.error("建立酒馆模式必须设定during大于20秒")
            return
        endif
        set tgr_sell = CreateTrigger()
        set tgr_random = CreateTrigger()
        set tgr_repick = CreateTrigger()
        call TriggerAddAction(tgr_sell, function thistype.buildDrunkerySellAction)
        call TriggerAddAction(tgr_random, function thistype.buildDrunkeryRandomAction)
        call TriggerAddAction(tgr_repick, function thistype.buildDrunkeryRepickAction)
        set during=during+1
        loop
            exitwhen i<=0 and heroId<=0
                set heroId = LoadInteger(hash_hero,0,hk_unit_type+i)
                if(heroId>0)then
                    set drunkeryNowQty = getDrunkeryQty(u)
                    if( u==null or drunkeryNowQty>=drunkery_allow_qty)then
                        set drunkeryNowQty = 0
                        if(rowNowQty>=buildPerRow)then
                            set rowNowQty = 0
                            set totalRow = totalRow+1
                            set x = buildX
                            set y = y-buildDistance
                        else
                            set x = buildX+rowNowQty*buildDistance
                        endif
                        set u = hunit.createUnitXY( player_passive,drunkeryID,x,y )
                        call TriggerRegisterUnitEvent( tgr_sell, u, EVENT_UNIT_SELL )
                        set rowNowQty = rowNowQty+1
                        call hunit.del(u,during)
                    endif
                    call add2drunkery(u,heroId)
                    call setDrunkeryQty(u,1+drunkeryNowQty)
                endif
                set i=i-1
        endloop
        //生成选英雄token
        set i = player_max_qty
        loop
            exitwhen i<=0
                call setPlayerUnitQty( players[i] , 0 )
                set u = hunit.createUnitXY( players[i], HERO_SELECTION_TOKEN ,buildX+buildPerRow*0.5*buildDistance,buildY-totalRow*0.5*buildDistance)
                call hunit.del(u,during)
                call TriggerRegisterPlayerChatEvent( tgr_random ,players[i],"-random",true)
                call TriggerRegisterPlayerChatEvent( tgr_repick ,players[i],"-repick",true)
            set i = i-1
        endloop
        //还剩10秒给个选英雄提示
        set t = htime.setTimeout(during-10.0,function thistype.tenSecTips)
        call htime.setTrigger(t,1,tgr_repick)
        call htime.setReal(t,2,buildX+buildPerRow*0.5*buildDistance)
        call htime.setReal(t,3,buildY-totalRow*0.5*buildDistance)
        //一定时间后clear
        set t = htime.setTimeout(during-0.5,function thistype.buildDrunkeryClear)
        call htime.setDialog(t,"选择英雄")
        call htime.setTrigger(t,1,tgr_sell)
        call htime.setTrigger(t,2,tgr_random)
    endmethod
	
    //todo -----------双击模式-----------

    private static method buildDoubleClickActionExpire takes nothing returns nothing
        local timer t = GetExpiredTimer()
        local integer pid = htime.getInteger(t,1)
        local integer uid = htime.getInteger(t,2)
        call SaveInteger(hash_hero,pid,uid,0)
    endmethod
    private static method buildDoubleClickAction takes nothing returns nothing
        local player p = GetTriggerPlayer()
        local unit u = GetTriggerUnit()
        local integer pid = GetHandleId(p)
        local integer uid = GetHandleId(u)
        local integer clickQty = 0
        local integer qty = getPlayerUnitQty(p)
        local location loc = null
        local integer max = getPlayerAllowQty()
        local timer t = null
        if(IsUnitInGroup(u,buildGroup)==false)then
            return
        endif
        if(qty>=max)then
            call hmsg.echoTo(p,"|cffffff80你已经选够单位|r",0)
            return
        endif
        set clickQty = 1+LoadInteger(hash_hero,pid,uid)
        set t = LoadTimerHandle(hash_hero,pid,-12523)
        if(t != null)then
            call htime.delTimer(t)
        endif
        if(clickQty<1)then
            set clickQty = 1
        endif
        call SaveInteger(hash_hero,pid,uid,clickQty)
        if(clickQty >= 2)then
            set qty = qty+1
            call setPlayerUnit(p,qty,u)
            call setPlayerUnitQty(p,qty)
            call GroupRemoveUnit(buildGroup,u)
            call SetUnitOwner( u, p , true )
            set loc = Location(bornX,bornY)
            call SetUnitPositionLoc(u,loc)
            call RemoveLocation(loc)
            set loc = null
            call PauseUnit(u, false )
            if(qty>=max)then
                call hmsg.echoTo(p,"您选择了 "+"|cffffff80"+GetUnitName(u)+"|r,已挑选完毕",0)
            else 
                call hmsg.echoTo(p,"您选择了 "+"|cffffff80"+GetUnitName(u)+"|r,还差 "+I2S(max-qty)+" 个",0)
            endif
        endif
        set t = htime.setTimeout(0.3,function thistype.buildDoubleClickActionExpire)
        call htime.setInteger(t,1,pid)
        call htime.setInteger(t,2,uid)
        call SaveTimerHandle(hash_hero,pid,-12523,t)
    endmethod

    private static method buildDoubleClickRandomAction takes nothing returns nothing
        local player p = GetTriggerPlayer()
        local integer max = getPlayerAllowQty()
        local integer qty = getPlayerUnitQty(p)
        local integer i = 0
        local unit u = null
        local string uname = ""
        local location loc = null
        if(qty>=max)then
            call hmsg.echoTo(p,"|cffffff80你已经选够单位|r",0)
            return
        endif
        set i = max
        set loc = Location(bornX,bornY)
        loop
            exitwhen(i<=qty)
                set u = GroupPickRandomUnit(buildGroup)
                call GroupRemoveUnit(buildGroup,u)
                if(u!=null)then
                    call SetUnitOwner( u, p , true )
                    call SetUnitPositionLoc(u,loc)
                    call PauseUnit(u, false )
                    set uname = uname+" "+GetUnitName(u)
                    call setPlayerUnit(p,i,u)
                endif
            set i = i-1
        endloop
        call RemoveLocation(loc)
        set loc = null
        call setPlayerUnitQty(p,max)
        call hmsg.echoTo(p,"已为您 |cffffff80random|r 选择了 "+"|cffffff80"+I2S(max-qty)+"|r 个单位：|cffffff80"+uname+"|r",0)
    endmethod

    private static method buildDoubleClickRepickAction takes nothing returns nothing
        local player p = GetTriggerPlayer()
        local integer qty = getPlayerUnitQty(p)
        local integer i = 0
        local unit u = null
        local location loc = null
        local real x = 0
        local real y = 0
        if(qty<=0)then
            call hmsg.echoTo(p,"|cffffff80你还没有选过任何单位|r",0)
            return
        endif
        set i = qty
        loop
            exitwhen i<=0
                set u = getPlayerUnit(p,i)
                set x = LoadReal(hash_hero,GetHandleId(u),9527)
                set y = LoadReal(hash_hero,GetHandleId(u),9528)
                set loc = Location(x,y)
                call SetUnitOwner( u, player_passive , true )
                call SetUnitPositionLocFacingBJ(u,loc, bj_UNIT_FACING )
                call RemoveLocation(loc)
                set loc = null
                call setPlayerUnit(p,i,null)
                call GroupAddUnit(buildGroup,u)
                call PauseUnit(u, true )
            set i = i-1
        endloop
        call setPlayerUnitQty(p,0)
        call hmsg.echoTo(p,"已为您 |cffffff80repick|r 了 "+"|cffffff80"+I2S(qty)+"|r 个单位",0)
    endmethod

    private static method buildDoubleClickClear takes nothing returns nothing
        local timer t = GetExpiredTimer()
        local trigger tgr_click = htime.getTrigger(t,1)
        local trigger tgr_random = htime.getTrigger(t,2)
        call htime.delTimer(t)
        call DisableTrigger( tgr_click )
        call DestroyTrigger( tgr_click )
        call DisableTrigger( tgr_random )
        call DestroyTrigger( tgr_random )
        call checkPlayerChooseOver()
    endmethod

    //开始建立单位给玩家双击
    //同时开启random指令
    //同时开启repick指令
    public static method buildDoubleClick takes real during returns nothing
        local integer i = getQty()
        local integer heroId = 0
        local unit u = null
        local unit hero = null
        local integer totalRow = 1
        local integer rowNowQty = 0
        local trigger tgr_click = null
        local trigger tgr_random = null
        local trigger tgr_repick = null
        local timer t = null
        local real x = 0
        local real y = buildY
        if(during<=20)then
            call hconsole.error("建立双击模式必须设定during大于20秒")
            return
        endif
        set tgr_click = CreateTrigger()
        set tgr_random = CreateTrigger()
        set tgr_repick = CreateTrigger()
        call TriggerAddAction(tgr_click, function thistype.buildDoubleClickAction)
        call TriggerAddAction(tgr_random, function thistype.buildDoubleClickRandomAction)
        call TriggerAddAction(tgr_repick, function thistype.buildDoubleClickRepickAction)
        set during=during+1
        if(buildGroup!=null)then
            call GroupClear(buildGroup)
            call DestroyGroup(buildGroup)
        endif
        set buildGroup = CreateGroup()
        loop
            exitwhen i<=0 and heroId<=0
                set heroId = LoadInteger(hash_hero,0,hk_unit_type+i)
                if(heroId>0)then
                    if(rowNowQty>=buildPerRow)then
                        set rowNowQty = 0
                        set totalRow = totalRow+1
                        set x = buildX
                        set y = y-buildDistance
                    else
                        set x = buildX+rowNowQty*buildDistance
                    endif
                    set u = hunit.createUnitXY( player_passive,heroId,x,y )
                    call SaveReal(hash_hero,GetHandleId(u),9527,x)
                    call SaveReal(hash_hero,GetHandleId(u),9528,y)
                    call GroupAddUnit(buildGroup,u)
                    call PauseUnit(u, true )
                    set rowNowQty = rowNowQty+1
                    call hunit.del(u,during)
                endif
                set i=i-1
        endloop
        //生成选英雄token
        set i = player_max_qty
        loop
            exitwhen i<=0
                call setPlayerUnitQty( players[i] , 0 )
                set u = hunit.createUnitXY( players[i], HERO_SELECTION_TOKEN ,buildX+buildPerRow*0.5*buildDistance,buildY-totalRow*0.5*buildDistance)
                call hunit.del(u,during)
                call TriggerRegisterPlayerSelectionEventBJ( tgr_click, players[i], true )
                call TriggerRegisterPlayerChatEvent( tgr_random ,players[i],"-random",true)
                call TriggerRegisterPlayerChatEvent( tgr_repick ,players[i],"-repick",true)
            set i = i-1
        endloop
        //还剩10秒给个选英雄提示
        set t = htime.setTimeout(during-10.0,function thistype.tenSecTips)
        call htime.setTrigger(t,1,tgr_repick)
        call htime.setReal(t,2,buildX+buildPerRow*0.5*buildDistance)
        call htime.setReal(t,3,buildY-totalRow*0.5*buildDistance)
        //一定时间后clear
        set t = htime.setTimeout(during-0.5,function thistype.buildDoubleClickClear)
        call htime.setDialog(t,"选择英雄")
        call htime.setTrigger(t,1,tgr_click)
        call htime.setTrigger(t,2,tgr_random)
    endmethod


endstruct
