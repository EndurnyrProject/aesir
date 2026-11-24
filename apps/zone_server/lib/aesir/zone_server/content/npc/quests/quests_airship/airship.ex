defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Airship do
  @moduledoc """
  Controls the international airship's voyage and monster invasion.

  ## Behavior

  - Announces destinations and opens or closes boarding warps on schedule.
  - Stages a monster attack and the captain's defense before resuming service.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "airplane_01",
        x: 1,
        y: 1,
        dir: 0,
        sprite: -1,
        name: "Airship",
        scope: :shared,
        unique_name: "Airship#airplane02"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer25000", ctx), do: ev_ontimer25000(ctx)
  def on_event("OnTimer30000", ctx), do: ev_ontimer30000(ctx)
  def on_event("OnTimer34000", ctx), do: ev_ontimer34000(ctx)
  def on_event("OnTimer38000", ctx), do: ev_ontimer38000(ctx)
  def on_event("OnTimer48000", ctx), do: ev_ontimer48000(ctx)
  def on_event("OnTimer48010", ctx), do: ev_ontimer48010(ctx)
  def on_event("OnTimer53000", ctx), do: ev_ontimer53000(ctx)
  def on_event("OnTimer58000", ctx), do: ev_ontimer58000(ctx)
  def on_event("OnTimer63000", ctx), do: ev_ontimer63000(ctx)
  def on_event("OnTimer68000", ctx), do: ev_ontimer68000(ctx)
  def on_event("OnTimer73000", ctx), do: ev_ontimer73000(ctx)
  def on_event("OnTimer73500", ctx), do: ev_ontimer73500(ctx)
  def on_event("OnTimer74000", ctx), do: ev_ontimer74000(ctx)
  def on_event("OnTimer74500", ctx), do: ev_ontimer74500(ctx)
  def on_event("OnTimer75000", ctx), do: ev_ontimer75000(ctx)
  def on_event("OnTimer75500", ctx), do: ev_ontimer75500(ctx)
  def on_event("OnTimer76000", ctx), do: ev_ontimer76000(ctx)
  def on_event("OnTimer76500", ctx), do: ev_ontimer76500(ctx)
  def on_event("OnTimer77000", ctx), do: ev_ontimer77000(ctx)
  def on_event("OnTimer77500", ctx), do: ev_ontimer77500(ctx)
  def on_event("OnTimer78000", ctx), do: ev_ontimer78000(ctx)
  def on_event("OnTimer79000", ctx), do: ev_ontimer79000(ctx)
  def on_event("OnTimer80000", ctx), do: ev_ontimer80000(ctx)
  def on_event("OnTimer81000", ctx), do: ev_ontimer81000(ctx)
  def on_event("OnTimer82000", ctx), do: ev_ontimer82000(ctx)
  def on_event("OnTimer83000", ctx), do: ev_ontimer83000(ctx)
  def on_event("OnTimer84000", ctx), do: ev_ontimer84000(ctx)
  def on_event("OnTimer85000", ctx), do: ev_ontimer85000(ctx)
  def on_event("OnTimer86000", ctx), do: ev_ontimer86000(ctx)
  def on_event("OnTimer87000", ctx), do: ev_ontimer87000(ctx)
  def on_event("OnTimer88000", ctx), do: ev_ontimer88000(ctx)
  def on_event("OnTimer93000", ctx), do: ev_ontimer93000(ctx)
  def on_event("OnTimer98000", ctx), do: ev_ontimer98000(ctx)
  def on_event("OnTimer103000", ctx), do: ev_ontimer103000(ctx)
  def on_event("OnTimer103500", ctx), do: ev_ontimer103500(ctx)
  def on_event("OnTimer104000", ctx), do: ev_ontimer104000(ctx)
  def on_event("OnTimer104500", ctx), do: ev_ontimer104500(ctx)
  def on_event("OnTimer105000", ctx), do: ev_ontimer105000(ctx)
  def on_event("OnTimer105500", ctx), do: ev_ontimer105500(ctx)
  def on_event("OnTimer106000", ctx), do: ev_ontimer106000(ctx)
  def on_event("OnTimer106500", ctx), do: ev_ontimer106500(ctx)
  def on_event("OnTimer107000", ctx), do: ev_ontimer107000(ctx)
  def on_event("OnTimer107500", ctx), do: ev_ontimer107500(ctx)
  def on_event("OnTimer108000", ctx), do: ev_ontimer108000(ctx)
  def on_event("OnTimer113000", ctx), do: ev_ontimer113000(ctx)
  def on_event("OnTimer118000", ctx), do: ev_ontimer118000(ctx)
  def on_event("OnTimer118500", ctx), do: ev_ontimer118500(ctx)
  def on_event("OnTimer119000", ctx), do: ev_ontimer119000(ctx)
  def on_event("OnTimer119500", ctx), do: ev_ontimer119500(ctx)
  def on_event("OnTimer120000", ctx), do: ev_ontimer120000(ctx)
  def on_event("OnTimer120500", ctx), do: ev_ontimer120500(ctx)
  def on_event("OnTimer121000", ctx), do: ev_ontimer121000(ctx)
  def on_event("OnTimer121500", ctx), do: ev_ontimer121500(ctx)
  def on_event("OnTimer122000", ctx), do: ev_ontimer122000(ctx)
  def on_event("OnTimer122500", ctx), do: ev_ontimer122500(ctx)
  def on_event("OnTimer123000", ctx), do: ev_ontimer123000(ctx)
  def on_event("OnTimer124000", ctx), do: ev_ontimer124000(ctx)
  def on_event("OnTimer125000", ctx), do: ev_ontimer125000(ctx)
  def on_event("OnTimer126000", ctx), do: ev_ontimer126000(ctx)
  def on_event("OnTimer127000", ctx), do: ev_ontimer127000(ctx)
  def on_event("OnTimer128000", ctx), do: ev_ontimer128000(ctx)
  def on_event("OnTimer133000", ctx), do: ev_ontimer133000(ctx)
  def on_event("OnTimer138000", ctx), do: ev_ontimer138000(ctx)
  def on_event("OnTimer143000", ctx), do: ev_ontimer143000(ctx)
  def on_event("OnTimer148000", ctx), do: ev_ontimer148000(ctx)
  def on_event("OnTimer400000", ctx), do: ev_ontimer400000(ctx)
  def on_event("OnTimer405000", ctx), do: ev_ontimer405000(ctx)
  def on_event("OnTimer410000", ctx), do: ev_ontimer410000(ctx)
  def on_event("OnTimer420000", ctx), do: ev_ontimer420000(ctx)
  def on_event("OnTimer430000", ctx), do: ev_ontimer430000(ctx)
  def on_event("OnTimer440000", ctx), do: ev_ontimer440000(ctx)
  def on_event("OnTimer465000", ctx), do: ev_ontimer465000(ctx)
  def on_event("OnTimer490000", ctx), do: ev_ontimer490000(ctx)
  def on_event("OnTimer500000", ctx), do: ev_ontimer500000(ctx)
  def on_event("OnTimer510000", ctx), do: ev_ontimer510000(ctx)
  def on_event("OnTimer520000", ctx), do: ev_ontimer520000(ctx)
  def on_event("OnTimer545000", ctx), do: ev_ontimer545000(ctx)
  def on_event("OnTimer570000", ctx), do: ev_ontimer570000(ctx)
  def on_event("OnTimer580000", ctx), do: ev_ontimer580000(ctx)
  def on_event("OnTimer590000", ctx), do: ev_ontimer590000(ctx)
  def on_event("OnTimer600000", ctx), do: ev_ontimer600000(ctx)
  def on_event("OnMyMobDead", ctx), do: ev_onmymobdead(ctx)
  def on_event("OnCaptainMobDead", ctx), do: ev_oncaptainmobdead(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_onenable(ctx) do
    initnpctimer(ctx)
  end

  def ev_ontimer25000(ctx) do
    mapannounce(ctx, "airplane_01", "We are heading to Izlude.", 1, 65280)
  end

  def ev_ontimer30000(ctx) do
    mapannounce(ctx, "airplane_01", "Captain: Attention, all passengers.", 1, 65280)
  end

  def ev_ontimer34000(ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "Captain: We are being approached by a group of unidentified creatures.",
      1,
      65280
    )
  end

  def ev_ontimer38000(ctx) do
    ctx
    |> mapannounce(
      "airplane_01",
      "Captain: All passengers on deck, please find shelter inside the ship!",
      1,
      65280
    )
    |> hideonnpc("Airship Staff#airplane01")
  end

  def ev_ontimer48000(ctx) do
    ctx =
      ctx
      |> summon_mob(
        mob_id: 1632,
        map: "airplane_01",
        at: {245, 57},
        event: "Airship#airplane02::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1632,
        map: "airplane_01",
        at: {247, 59},
        event: "Airship#airplane02::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1632,
        map: "airplane_01",
        at: {249, 52},
        event: "Airship#airplane02::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1632,
        map: "airplane_01",
        at: {243, 62},
        event: "Airship#airplane02::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1633,
        map: "airplane_01",
        at: {239, 52},
        event: "Airship#airplane02::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1633,
        map: "airplane_01",
        at: {234, 56},
        event: "Airship#airplane02::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1633,
        map: "airplane_01",
        at: {227, 49},
        event: "Airship#airplane02::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1633,
        map: "airplane_01",
        at: {233, 41},
        event: "Airship#airplane02::OnMyMobDead"
      )
      |> set_local(:x, [251, 245, 234, 233])
      |> set_local(:y, [47, 53, 46, 58])
      |> set_local(:i, 0)
      |> spawn_random_invaders()
      |> set_local(:mob_list, [1111, 1392, 1005, 1049, 1042])

    ctx = set_local(ctx, :mob_id, Enum.at(get_local(ctx, :mob_list, []), :rand.uniform(5) - 1, 0))

    ctx =
      summon_mob(ctx,
        mob_id: get_local(ctx, :mob_id, 0),
        map: "airplane_01",
        at: {243, 60},
        name: "--ja--",
        event: "Airship#airplane02::OnMyMobDead"
      )

    ctx =
      summon_mob(ctx,
        mob_id: get_local(ctx, :mob_id, 0),
        map: "airplane_01",
        at: {228, 54},
        name: "--ja--",
        event: "Airship#airplane02::OnMyMobDead"
      )

    summon_mob(ctx,
      mob_id: get_local(ctx, :mob_id, 0),
      map: "airplane_01",
      at: {232, 41},
      name: "--ja--",
      event: "Airship#airplane02::OnMyMobDead"
    )
  end

  def ev_ontimer48010(ctx) do
    ctx
    |> summon_mob(
      mob_id: 1632,
      map: "airplane_01",
      at: {238, 56},
      event: "Airship#airplane02::OnCaptainMobDead"
    )
    |> summon_mob(
      mob_id: 1632,
      map: "airplane_01",
      at: {239, 56},
      event: "Airship#airplane02::OnCaptainMobDead"
    )
    |> summon_mob(
      mob_id: 1632,
      map: "airplane_01",
      at: {240, 50},
      event: "Airship#airplane02::OnCaptainMobDead"
    )
    |> summon_mob(
      mob_id: 1632,
      map: "airplane_01",
      at: {241, 56},
      event: "Airship#airplane02::OnCaptainMobDead"
    )
    |> summon_mob(
      mob_id: 1632,
      map: "airplane_01",
      at: {247, 51},
      event: "Airship#airplane02::OnCaptainMobDead"
    )
    |> summon_mob(
      mob_id: 1633,
      map: "airplane_01",
      at: {237, 44},
      event: "Airship#airplane02::OnCaptainMobDead"
    )
    |> summon_mob(
      mob_id: 1633,
      map: "airplane_01",
      at: {233, 54},
      event: "Airship#airplane02::OnCaptainMobDead"
    )
    |> summon_mob(
      mob_id: 1633,
      map: "airplane_01",
      at: {237, 62},
      event: "Airship#airplane02::OnCaptainMobDead"
    )
  end

  def ev_ontimer53000(ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "Attendant: Captain Tarlock, we're in trouble! The monsters are heading to the propellers!",
      1,
      65280
    )
  end

  def ev_ontimer58000(ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "Captain Tarlock: What?! I've got to stop them!",
      1,
      7_396_315
    )
  end

  def ev_ontimer63000(ctx) do
    ctx |> hideonnpc("Airship Captain#01") |> hideoffnpc("Airship Captain#02")
  end

  def ev_ontimer68000(ctx) do
    ctx
    |> emotion(:anger, getnpcid(ctx, "Airship Captain#02"))
    |> mapannounce(
      "airplane_01",
      "Captain Tarlock: You ugly, godforsaken creatures... Get off my ship!",
      1,
      7_396_315
    )
  end

  def ev_ontimer73000(ctx) do
    ctx
    |> mapannounce("airplane_01", "*Kzzz...Drrrr...Boom! CRASH!*", 1, 65280)
    |> specialeffect(:sui_explosion, :area, "boom6#airplane")
  end

  def ev_ontimer73500(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom7#airplane")
  end

  def ev_ontimer74000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom8#airplane")
  end

  def ev_ontimer74500(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom9#airplane")
  end

  def ev_ontimer75000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom10#airplane")
  end

  def ev_ontimer75500(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom6#airplane")
  end

  def ev_ontimer76000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom7#airplane")
  end

  def ev_ontimer76500(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom8#airplane")
  end

  def ev_ontimer77000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom9#airplane")
  end

  def ev_ontimer77500(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom10#airplane")
  end

  def ev_ontimer78000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom6#airplane")
    |> mapannounce(
      "airplane_01",
      "Engineer: Oh no! We've got a problem with the Number One Rear Engine!",
      1,
      65280
    )
  end

  def ev_ontimer79000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom7#airplane")
  end

  def ev_ontimer80000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom8#airplane")
  end

  def ev_ontimer81000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom9#airplane")
  end

  def ev_ontimer82000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom10#airplane")
  end

  def ev_ontimer83000(ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "Pilot: Hurry! Get the women, old people and children somewhere safe first! Hurry!",
      1,
      65280
    )
  end

  def ev_ontimer84000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom6#airplane")
  end

  def ev_ontimer85000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom7#airplane")
  end

  def ev_ontimer86000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom8#airplane")
  end

  def ev_ontimer87000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom7#airplane")
  end

  def ev_ontimer88000(ctx) do
    ctx
    |> emotion(:anger, getnpcid(ctx, "Airship Captain#02"))
    |> mapannounce(
      "airplane_01",
      "Captain Tarlock: You dirty monsters are dealing with this ship's captain...",
      1,
      7_396_315
    )
  end

  def ev_ontimer93000(ctx) do
    ctx
    |> emotion(:anger, getnpcid(ctx, "Airship Captain#02"))
    |> mapannounce(
      "airplane_01",
      "Captain Tarlock: I'll protect this ship and my crew with my life!",
      1,
      7_396_315
    )
  end

  def ev_ontimer98000(ctx) do
    ctx
    |> emotion(:hng, getnpcid(ctx, "Airship Captain#02"))
    |> mapannounce(
      "airplane_01",
      "Captain Tarlock: Here goes! Special Exodus Joker XIII Doom Rifle!",
      1,
      7_396_315
    )
  end

  def ev_ontimer103000(ctx) do
    ctx
    |> mapannounce("airplane_01", "*Bang! Bang Bang! Bang Bang! Bang Bang Bang!*", 1, 65280)
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer103500(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom1#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer104000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom2#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer104500(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom3#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer105000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom4#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer105500(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom5#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer106000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom0#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer106500(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom1#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer107000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom2#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer107500(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom4#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer108000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom5#airplane")
    |> killmonster("airplane_01", "Airship#airplane02::OnCaptainMobDead")
  end

  def ev_ontimer113000(ctx) do
    ctx
    |> emotion(:hng, getnpcid(ctx, "Airship Captain#02"))
    |> mapannounce(
      "airplane_01",
      "Captain Tarlock: Filthy animals! Stop ruining my ship!",
      1,
      7_396_315
    )
  end

  def ev_ontimer118000(ctx) do
    ctx
    |> mapannounce("airplane_01", "*Bang! Bang Bang! Bang Bang! Bang Bang Bang!*", 1, 65280)
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer118500(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom6#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer119000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom7#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer119500(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom8#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer120000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom9#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer120500(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom10#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer121000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom6#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer121500(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom7#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer122000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom8#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer122500(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom9#airplane")
    |> specialeffect(:hit5, :area, "Airship Captain#02")
  end

  def ev_ontimer123000(ctx) do
    ctx
    |> specialeffect(:sui_explosion, :area, "boom8#airplane")
    |> mapannounce("airplane_01", "*Boom! Boom Boom! Boom Boom! Boom!*", 1, 65280)
  end

  def ev_ontimer124000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom9#airplane")
  end

  def ev_ontimer125000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom10#airplane")
  end

  def ev_ontimer126000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom6#airplane")
  end

  def ev_ontimer127000(ctx) do
    specialeffect(ctx, :sui_explosion, :area, "boom7#airplane")
  end

  def ev_ontimer128000(ctx) do
    ctx
    |> emotion(:fret, getnpcid(ctx, "Airship Captain#02"))
    |> mapannounce("airplane_01", "Captain Tarlock: There's... Too many to handle!", 1, 7_396_315)
  end

  def ev_ontimer133000(ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "Pilot: Captain, sir, the situation is getting critical!",
      1,
      65280
    )
  end

  def ev_ontimer138000(ctx) do
    ctx
    |> emotion(:sweat, getnpcid(ctx, "Airship Captain#02"))
    |> mapannounce(
      "airplane_01",
      "Captain Tarlock: We'll need all the help we can get!",
      1,
      7_396_315
    )
  end

  def ev_ontimer143000(ctx) do
    ctx
    |> emotion(:sorry, getnpcid(ctx, "Airship Captain#02"))
    |> mapannounce(
      "airplane_01",
      "Captain Tarlock: All hands and any passenger who can fight! We've got to drive away these monsters!",
      1,
      7_396_315
    )
  end

  def ev_ontimer148000(ctx) do
    ctx |> hideonnpc("Airship Captain#02") |> hideoffnpc("Airship Captain#01")
  end

  def ev_ontimer400000(ctx) do
    killmonster(ctx, "airplane_01", "Airship#airplane02::OnMyMobDead")
  end

  def ev_ontimer405000(ctx) do
    ctx
    |> mapannounce(
      "airplane_01",
      "Monster threat eliminated. The Airship is now returning to normal operation.",
      1,
      65280
    )
    |> hideoffnpc("Airship Staff#airplane01")
  end

  def ev_ontimer410000(ctx) do
    mapannounce(ctx, "airplane_01", "We will arrive in Izlude shortly.", 1, "0x00ff00")
  end

  def ev_ontimer420000(ctx) do
    ctx
    |> set_server_temp_var("airplanelocation2", 1)
    |> donpcevent("#AirshipWarp-3::OnUnhide")
    |> donpcevent("#AirshipWarp-4::OnUnhide")
    |> mapannounce("airplane_01", "Welcome to Izlude. Have a safe trip.", 1, "0x00ff00")
  end

  def ev_ontimer430000(ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "We are currently in Izlude. The Airship will take off shortly.",
      1,
      "0x00ff00"
    )
  end

  def ev_ontimer440000(ctx) do
    ctx
    |> donpcevent("#AirshipWarp-3::OnHide")
    |> donpcevent("#AirshipWarp-4::OnHide")
    |> mapannounce(
      "airplane_01",
      "The Airship is now taking off. Our next destination is Juno.",
      1,
      "0x70dbdb"
    )
  end

  def ev_ontimer465000(ctx) do
    mapannounce(ctx, "airplane_01", "We are heading to Juno.", 1, "0x70dbdb")
  end

  def ev_ontimer490000(ctx) do
    mapannounce(ctx, "airplane_01", "We will arrive in Juno shortly.", 1, "0x70dbdb")
  end

  def ev_ontimer500000(ctx) do
    ctx
    |> set_server_temp_var("airplanelocation2", 2)
    |> donpcevent("#AirshipWarp-3::OnUnhide")
    |> donpcevent("#AirshipWarp-4::OnUnhide")
    |> mapannounce("airplane_01", "Welcome to Juno. Have a safe trip.", 1, "0x70dbdb")
  end

  def ev_ontimer510000(ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "We are currently in Juno. The Airship will leave shortly.",
      1,
      "0x70dbdb"
    )
  end

  def ev_ontimer520000(ctx) do
    ctx
    |> donpcevent("#AirshipWarp-3::OnHide")
    |> donpcevent("#AirshipWarp-4::OnHide")
    |> mapannounce(
      "airplane_01",
      "The Airship is leaving the ground. Our next destination is Rachel.",
      1,
      "0xFF8200"
    )
  end

  def ev_ontimer545000(ctx) do
    mapannounce(ctx, "airplane_01", "We are heading to Rachel.", 1, "0xFF8200")
  end

  def ev_ontimer570000(ctx) do
    mapannounce(ctx, "airplane_01", "We will arrive in Rachel shortly.", 1, "0xFF8200")
  end

  def ev_ontimer580000(ctx) do
    ctx
    |> set_server_temp_var("airplanelocation2", 0)
    |> donpcevent("#AirshipWarp-3::OnUnhide")
    |> donpcevent("#AirshipWarp-4::OnUnhide")
    |> mapannounce("airplane_01", "Welcome to Rachel. Have a safe trip.", 1, "0xFF8200")
  end

  def ev_ontimer590000(ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "We are currently in Rachel. The Airship will take off shortly.",
      1,
      "0xFF8200"
    )
  end

  def ev_ontimer600000(ctx) do
    ctx
    |> donpcevent("#AirshipWarp-3::OnHide")
    |> donpcevent("#AirshipWarp-4::OnHide")
    |> mapannounce(
      "airplane_01",
      "The Airship is now taking off. Our next destination is Izlude.",
      1,
      "0x00ff00"
    )
    |> stopnpctimer()
    |> set_npc_var_of("moninv", "International_Airship", 2)
    |> donpcevent("International_Airship::OnEnable")
  end

  def ev_onmymobdead(ctx) do
    ev_oncaptainmobdead(ctx)
  end

  def ev_oncaptainmobdead(ctx) do
    ctx
  end

  defp spawn_random_invaders(ctx) do
    Enum.reduce(1..4, ctx, fn _, ctx ->
      mob_id = Enum.at([1111, 1392, 1005, 1049, 1042], Enum.random(1..5) - 1)
      index = get_local(ctx, :i, 0)

      name = if mob_id == 1005, do: [name: "Farmiliar"], else: []

      ctx
      |> summon_mob(
        [
          mob_id: mob_id,
          map: "airplane_01",
          at:
            {Enum.at(get_local(ctx, :x, []), index, 0), Enum.at(get_local(ctx, :y, []), index, 0)}
        ] ++ name ++ [event: "Airship#airplane02::OnMyMobDead"]
      )
      |> set_local(:i, index + 1)
    end)
  end
end
