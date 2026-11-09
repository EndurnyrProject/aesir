defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.WishMaiden do
  @moduledoc """
  Checks a castle guild’s preparations and opens the trials of Okolnir.

  ## Behavior

  - Requires the owning guild and its leader to prepare the required offerings.
  - Explains the trials and opens the gate when 16 to 20 members are present.
  - Rejects outsiders and announces the guild that opens Okolnir.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - L0ne_W0lf
    - Toshiro90
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/okolnir.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_qaru01",
        x: 345,
        y: 82,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#gq_aru01"
      },
      %{
        map: "que_qaru02",
        x: 345,
        y: 82,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#gq_aru02"
      },
      %{
        map: "que_qaru03",
        x: 345,
        y: 82,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#gq_aru03"
      },
      %{
        map: "que_qaru04",
        x: 345,
        y: 82,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#gq_aru04"
      },
      %{
        map: "que_qaru05",
        x: 345,
        y: 82,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#gq_aru05"
      },
      %{
        map: "que_qsch01",
        x: 345,
        y: 82,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#gq_sch01"
      },
      %{
        map: "que_qsch02",
        x: 345,
        y: 82,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#gq_sch02"
      },
      %{
        map: "que_qsch03",
        x: 345,
        y: 82,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#gq_sch03"
      },
      %{
        map: "que_qsch04",
        x: 345,
        y: 82,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#gq_sch04"
      },
      %{
        map: "que_qsch05",
        x: 345,
        y: 82,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#gq_sch05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = identify_realm(ctx)

    castle_prefix =
      if Rathena.truthy?(Rathena.compare(strnpcinfo(ctx, 4), "aru")),
        do: "arug_cas0",
        else: "schg_cas0"

    castle_index = Rathena.charat(strnpcinfo(ctx, 4), Rathena.getstrlen(strnpcinfo(ctx, 4)) - 1)
    ctx = set_local(ctx, :"t$", "#{castle_prefix}#{castle_index}")
    ctx = set_local(ctx, :GID, castle_data(ctx, get_local(ctx, :"t$", ""), 1))

    if getcharid(ctx, 2) == get_local(ctx, :GID, 0) do
      ctx = cutin(ctx, "wish_maiden31", 1)

      if is_guild_leader(ctx) == 1 do
        prepare_trials(ctx)
      else
        ctx
        |> cutin("wish_maiden31", 1)
        |> introduce_maiden()
        |> mes("[Wish Maiden]")
        |> mes("Bring me the one who brought you to this place.")
        |> mes(".. Deliver him to my will.")
        |> close()
        |> cutin("wish_maiden11", 255)
      end
    else
      ctx
      |> cutin("wish_maiden13", 1)
      |> mes("[Wish Maiden]")
      |> mes("...You are not qualified.")
      |> close()
      |> percent_heal(hp: -100, sp: 0)
      |> cutin("wish_maiden11", 255)
    end
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    ctx = identify_realm(ctx)
    suffix = get_local(ctx, :"sub$", "")

    if Rathena.truthy?(getd(ctx, "$siz_#{suffix}_on")) do
      disablenpc(ctx, "Wish Maiden#gq_#{suffix}")
    else
      enablenpc(ctx, "Wish Maiden#gq_#{suffix}")
    end
  end

  defp identify_realm(ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    set_local(ctx, :"sub$", suffix)
  end

  defp introduce_maiden(ctx) do
    ctx
    |> mes("[Wish Maiden]")
    |> mes("I am... Wish maiden.")
    |> mes("Mourning in this virtual realm, Okolnir.")
    |> mes("On behalf of the humanbeings who defeated God here.")
    |> next()
  end

  defp prepare_trials(ctx) do
    ctx = ctx |> introduce_maiden() |> check_offerings()

    if get_local(ctx, :check, 0) >= 9 do
      offer_trials(ctx)
    else
      ctx
      |> explain_offerings()
      |> cutin("wish_maiden11", 255)
    end
  end

  defp check_offerings(ctx) do
    offerings =
      if Rathena.truthy?(Rathena.compare(get_local(ctx, :"sub$", ""), "aru")) do
        [7835, 1, 7836, 1, 7837, 1, 7838, 1, 2513, 1, 7291, 10, 7293, 10, 7063, 100, 985, 20]
      else
        [7830, 1, 7831, 1, 7832, 1, 7833, 1, 7834, 1, 2357, 1, 7510, 100, 969, 10, 985, 20]
      end

    ctx = ctx |> set_local(:n, offerings) |> set_local(:i, 0)

    offerings
    |> Enum.chunk_every(2)
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {[item_id, amount], index}, ctx ->
      ctx =
        if count_item(ctx, item_id) >= amount do
          set_local(ctx, :check, get_local(ctx, :check, 0) + 1)
        else
          ctx
        end

      set_local(ctx, :i, (index + 1) * 2)
    end)
  end

  defp offer_trials(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("wish_maiden11", 1)
      |> mes("[Wish Maiden]")
      |> mes("Are you ready to endure the trials to get the Goddess' glory?")
      |> next()
      |> select(["Yes, I am", "Sorry, I'll try later"])

    case choice do
      1 ->
        explain_trials(ctx)

      2 ->
        ctx
        |> cutin("wish_maiden32", 1)
        |> mes("[Wish Maiden]")
        |> mes("... Are you afraid of")
        |> mes("the trials facing you?")
        |> mes("....")
        |> next()
        |> cutin("wish_maiden13", 1)
        |> mes("[Wish Maiden]")
        |> mes("Do you think that you can defeat the Goddess shine easily?")
        |> mes("I feel disappointed by all of you.")
        |> mes("Just go away...")
        |> close()
        |> cutin("wish_maiden11", 255)

      _ ->
        ctx
    end
  end

  defp explain_trials(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("wish_maiden12", 1)
      |> mes("[Wish Maiden]")
      |> mes("I will test whether or not you deserve the Goddess shine...")
      |> mes("Isn't it simple?")
      |> next()
      |> mes("[Wish Maiden]")
      |> mes("Okolnir is a virtual place.")
      |> mes("There is no room for error there.")
      |> mes("^ff0000You only have one hour.^000000")
      |> next()
      |> cutin("wish_maiden31", 1)
      |> mes("[Wish Maiden]")
      |> mes(
        "If you have not finished in that time, Okolnir will be destroyed, and I will go to rest."
      )
      |> mes("You will have to wait again...")
      |> next()
      |> mes("[Wish Maiden]")
      |> mes("Are you ready to go through?")
      |> mes("^4d4dffYou need to have 16 to 20 members present^000000.")
      |> next()
      |> cutin("wish_maiden11", 1)
      |> mes("[Wish Maiden]")
      |> mes("I will open the gate of Okolnir if your members are ready.")
      |> next()
      |> select(["We are ready.", "We need more time."])

    case choice do
      1 ->
        check_participants(ctx)

      2 ->
        ctx
        |> cutin("wish_maiden13", 1)
        |> mes("[Wish Maiden]")
        |> mes("Don't hesitate to try.")
        |> mes("You should catch the chance when it comes to you.")
        |> mes("Just gather your fellow members.")
        |> close()
        |> cutin("wish_maiden11", 255)

      _ ->
        ctx
    end
  end

  defp check_participants(ctx) do
    ctx = set_local(ctx, :saram, getmapusers(ctx, "que_q#{get_local(ctx, :"sub$", "")}"))
    participants = get_local(ctx, :saram, 0)

    if participants > 15 and participants < 21 do
      open_gate(ctx)
    else
      ctx
      |> cutin("wish_maiden13", 1)
      |> mes("[Wish Maiden]")
      |> mes("You need to have 16 to 20 members present to open the gate of Okolnir.")
      |> mes("Come back when you are ready.")
      |> close()
      |> cutin("wish_maiden11", 255)
    end
  end

  defp open_gate(ctx) do
    suffix = get_local(ctx, :"sub$", "")

    ctx =
      ctx
      |> cutin("wish_maiden12", 1)
      |> mes("[Wish Maiden]")
      |> mes("Now I will open the gate of Okolnir where I am.")
      |> mes("I will wait for you on the top of Okolnir...")
      |> next()
      |> mes("[Wish Maiden]")
      |> mes(
        "I hope that you can complete all of the trials before the virtual Okolnir is destroyed..."
      )
      |> mes("Good luck.")
      |> mapannounce(
        "que_q#{suffix}",
        "Wish Maiden: The gate of Okolnir is open! Don't forget you only have one hour.",
        1,
        "0x00ff00"
      )
      |> close()
      |> setd("$@gqse_#{suffix}_pcc", get_local(ctx, :saram, 0))
      |> setd("$siz_#{suffix}_on", 1)
      |> donpcevent("#okolnir_#{suffix}::OnEnable")
      |> disablenpc("Wish Maiden#gq_#{suffix}")
      |> cutin("wish_maiden11", 255)

    announce(
      ctx,
      "[#{char_name(ctx, 0)}], of the guild [#{getguildname(ctx, get_local(ctx, :GID, 0))}] has opened the gates to the realm of Okolnir.",
      0,
      "0x70dbdb"
    )
  end

  defp explain_offerings(ctx) do
    ctx =
      ctx
      |> cutin("wish_maiden11", 1)
      |> mes("[Wish Maiden]")
      |> mes("Do you wish to enter?")
      |> mes("Only those prepared may enter here.")
      |> mes("You must bring several items to enter Okolnir.")
      |> next()
      |> mes("[Wish Maiden]")

    ctx =
      if Rathena.truthy?(Rathena.compare(get_local(ctx, :"sub$", ""), "aru")) do
        ctx
        |> mes("Dusk Glow")
        |> mes("Dawn Essence")
        |> mes("Cold Moonlight")
        |> mes("Hazy Starlight.")
        |> next()
        |> mes("[Wish Maiden]")
        |> mes("Please bring those four things, 10 Agate, 10 Rose Quartz, and 20 Elunium,")
        |> mes("a Heavenly Maiden's Robe, as well as 100 Soft feathers.")
      else
        ctx
        |> mes("Goddess Tear")
        |> mes("Valkyrie's Token")
        |> mes("Brynhild Armor Piece")
        |> mes("Hero Remains")
        |> mes("Valkyrie Armor")
        |> mes("Andvari's Ring.")
        |> next()
        |> mes("[Wish Maiden]")
        |> mes("You must bring those six things, 10 Gold, and 20 Elunium.")
        |> mes("Many Valhala's Flowers are also required as an offering.")
      end

    ctx
    |> next()
    |> mes("[Wish Maiden]")
    |> mes("Once all of those are prepared, the gate will open.")
    |> next()
    |> mes("[Wish Maiden]")
    |> mes(".... ")
    |> mes(
      "...........The Goddess shines brightly down on you, you should be stronger to deserve it..."
    )
    |> next()
    |> mes("[Wish Maiden]")
    |> mes("Remember...")
    |> mes("You need to collect many soft feathers.")
    |> mes("I hope that your dreams come true.")
    |> next()
    |> mes("[Wish Maiden]")
    |> mes("I will answer all your requests if you bring these to me.")
    |> close()
  end
end
