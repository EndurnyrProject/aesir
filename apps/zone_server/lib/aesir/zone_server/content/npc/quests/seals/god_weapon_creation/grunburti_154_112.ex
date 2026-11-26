defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.GodWeaponCreation.Grunburti154112 do
  @moduledoc """
  The dwarf Grunburti forges one godly item for the guild master who reaches his underground
  laboratory while all four seals are released.

  ## Behavior

  - Once a godly item has been forged and the seals are restored, he only mocks visitors.
  - Anyone who is not a guild master is told to get out.
  - A guild master picks Brisingamen, Megingjard, Sleipnir or Mjolnir and hears its materials;
    with all of them in hand he forges the item, unless the seals were restored meanwhile.
  - Forging takes the materials, hands over the item, restores every seal and announces the new
    owner and their guild to the server.
  - Entering the laboratory starts a ten minute timer: he warns the map at the start and at the
    end, then opens the way out and lets the next guild master in.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god01",
        x: 154,
        y: 112,
        dir: 4,
        sprite: 826,
        name: "Grunburti",
        scope: :shared,
        unique_name: "Grunburti#god"
      }
    ]

  @header "[Dwarf Grunburti]"

  @seals ["God1", "God2", "God3", "God4"]

  @materials %{
    brisingamen: [
      {7073, 4},
      {7077, 4},
      {7088, 3},
      {7090, 3},
      {7092, 3},
      {726, 2},
      {722, 3},
      {727, 10},
      {724, 5},
      {969, 20},
      {2603, 1}
    ],
    megingjard: [{7058, 1}, {969, 20}, {726, 10}, {984, 10}, {2627, 1}],
    sleipnir: [
      {7076, 3},
      {7079, 5},
      {7083, 3},
      {7086, 4},
      {7087, 3},
      {969, 20},
      {985, 10},
      {2406, 1}
    ],
    mjolnir: [
      {7074, 2},
      {7075, 4},
      {7078, 5},
      {7089, 5},
      {7091, 5},
      {984, 20},
      {985, 5},
      {969, 40},
      {1522, 1}
    ]
  }

  @rewards %{brisingamen: 2630, megingjard: 2629, sleipnir: 2410, mjolnir: 1530}

  @names %{
    brisingamen: "Brisingamen",
    megingjard: "Megingjard",
    sleipnir: "Sleipnir",
    mjolnir: "Mjolnir"
  }

  @impl true
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  def on_event("OnTimer10000", ctx) do
    mapannounce(ctx, "que_god01", "Remember that you only have 10 minutes for this! Hurry up!", 1)
  end

  def on_event("OnTimer610000", ctx) do
    mapannounce(
      ctx,
      "que_god01",
      "You're too slow! I'm going to give another human a chance! Next!",
      1
    )
  end

  def on_event("OnTimer612000", ctx), do: donpcevent(ctx, "god_wep_warpmaster::OnEnable")

  def on_event("OnTimer615000", ctx) do
    ctx
    |> donpcevent("god_wep_warpmaster::OnDisable")
    |> donpcevent("#god_hopewarp1::OnReset")
    |> stopnpctimer()
  end

  @impl true
  def on_talk(ctx) do
    if seal_holds?(ctx) do
      ctx
      |> mes(@header)
      |> mes("One of the godly")
      |> mes("items has been created,")
      |> mes("and the seals have been")
      |> mes("restored. You'll have to")
      |> mes("wait until they're all")
      |> mes("released again...!")
      |> pity()
    else
      ctx = set_local(ctx, :GID, getcharid(ctx, 2))

      if is_guild_leader(ctx) == 0 do
        intruder(ctx)
      else
        choose_item(ctx)
      end
    end
  end

  defp seal_holds?(ctx) do
    Enum.any?(@seals, fn seal ->
      get_server_var(ctx, seal, 0) < get_server_temp_var(ctx, "god_check2", 0)
    end)
  end

  defp pity(ctx) do
    ctx
    |> next()
    |> mes(@header)
    |> mes("Bwahahahahahahaa!")
    |> mes("Even though you're")
    |> mes("just a human, I feel")
    |> mes("pity for you~")
    |> close()
  end

  defp intruder(ctx) do
    ctx
    |> mes(@header)
    |> mes("How in the...")
    |> mes("Get out of here!")
    |> next()
    |> mes(@header)
    |> mes("How did one of you")
    |> mes("stupid humans get in")
    |> mes("here?! Only those who")
    |> mes("hold the Emperium can")
    |> mes("even think of entering")
    |> mes("this place...!")
    |> close()
  end

  defp choose_item(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@header)
      |> mes("It's incredibly")
      |> mes(
        "humiliating to do work for a human. But since destiny has chosen you as the bearer of an Emperium, I have no choice but to oblige your requests."
      )
      |> next()
      |> mes(@header)
      |> mes("We only have")
      |> mes(
        "^FF000010 minutes^000000 to recreate one godly treasure. After that, the seals will restore themselves and I won't be able to create anything until they're released again..."
      )
      |> next()
      |> mes(@header)
      |> mes("^FF0000Don't be too slow^000000,")
      |> mes("otherwise ^FF0000I will give")
      |> mes("the chance to another")
      |> mes("human^000000 right away!")
      |> next()
      |> mes(@header)
      |> mes("Now...!")
      |> mes("Choose the item")
      |> mes("you wish for me")
      |> mes("to create!")
      |> next()
      |> select(["Brisingamen", "Megingjard", "Sleipnir", "Mjolnir"])

    case choice do
      1 -> offer(ctx, :brisingamen)
      2 -> offer(ctx, :megingjard)
      3 -> offer(ctx, :sleipnir)
      4 -> offer(ctx, :mjolnir)
      _ -> ctx
    end
  end

  defp offer(ctx, item) do
    {ctx, choice} =
      ctx
      |> introduce(item)
      |> mes(@header)
      |> mes("Once again, I need following materials in order to reproduce")
      |> mes("this godly treasure...")
      |> next()
      |> list_materials(item)
      |> next()
      |> select(["Make #{@names[item]}.", "Cancel."])

    case choice do
      1 ->
        craft(ctx, item)

      2 ->
        ctx
        |> mes(@header)
        |> mes("Muhahahaha~")
        |> mes("Somehow, I figured")
        |> mes("you'd back out, human!")
        |> close()

      _ ->
        ctx
    end
  end

  defp craft(ctx, item) do
    if has_materials?(ctx, item) do
      ctx = ctx |> start_work(item) |> next()

      if seal_holds?(ctx) do
        ctx
        |> mes(@header)
        |> mes("But...")
        |> mes("The seals")
        |> mes("have just been")
        |> mes("restored. You'll have to")
        |> mes("wait until they're all")
        |> mes("released again...!")
        |> pity()
      else
        forge(ctx, item)
      end
    else
      missing_materials(ctx, item)
    end
  end

  defp has_materials?(ctx, item) do
    Enum.all?(@materials[item], fn {item_id, amount} -> count_item(ctx, item_id) >= amount end)
  end

  defp forge(ctx, item) do
    ctx =
      @materials[item]
      |> Enum.reduce(ctx, fn {item_id, amount}, ctx -> delitem(ctx, item_id, amount) end)
      |> give_item(@rewards[item], 1)

    ctx = Enum.reduce(@seals, ctx, &set_server_var(&2, &1, 0))

    message =
      announcement(item, char_name(ctx, 0), getguildname(ctx, get_local(ctx, :GID, 0)))

    ctx
    |> announce(message, 0)
    |> farewell(item)
    |> close()
  end

  defp announcement(:brisingamen, player, guild) do
    "[Brisingamen] has come into the hands of [#{player}], master of the [#{guild}] guild."
  end

  defp announcement(:mjolnir, player, guild) do
    "[Mjolnir] has been bestowed to [#{player}], the master of the [#{guild}] guild."
  end

  defp announcement(item, player, guild) do
    "[#{@names[item]}] the godly item has been given to [#{player}], the master of the guild [#{guild}]."
  end

  defp missing_materials(ctx, :mjolnir) do
    ctx
    |> mes(@header)
    |> mes("Idiot human!")
    |> mes("You didn't bring")
    |> mes("everything I need")
    |> mes("to recreate Mjolnir!")
    |> mes("Hurry...!")
    |> close()
  end

  defp missing_materials(ctx, item) do
    ctx
    |> mes(@header)
    |> mes("Idiot human!")
    |> mes("You didn't bring")
    |> mes("everything I need to")
    |> mes("recreate #{@names[item]}!")
    |> mes("Hurry...!")
    |> close()
  end

  defp introduce(ctx, :brisingamen) do
    ctx
    |> mes(@header)
    |> mes("B-Brisingamen?!")
    |> mes("I've never expected")
    |> mes("such insolence...!")
    |> mes(
      "This necklace will never have any meaning in my eyes unless it's worn by the goddess Freya."
    )
    |> next()
    |> mes(@header)
    |> mes("But who am I to judge your worthiness? These treasures")
    |> mes(
      "select their owners with their own will. Let's see if Brisingamen will find you worthy!"
    )
    |> next()
  end

  defp introduce(ctx, :megingjard) do
    ctx
    |> mes(@header)
    |> mes("M- Megingjard?!")
    |> mes("The girdle of might?!")
    |> next()
    |> mes(@header)
    |> mes(
      "This belt was worn long ago by Thor, the mightest warrior ever. But since these treasures select their owners, we'll see whether or not it recognizes you as worthy!"
    )
    |> next()
  end

  defp introduce(ctx, :sleipnir) do
    ctx
    |> mes(@header)
    |> mes("Sleipnir...")
    |> mes("Now, understand")
    |> mes("that I can't create")
    |> mes("the eight-legged stallion")
    |> mes("of legend. However...")
    |> next()
    |> mes(@header)
    |> mes("I can create a pair")
    |> mes(
      "of shoes that will possess the power of Sleipnir. It's a strange, but feasible process..."
    )
    |> next()
  end

  defp introduce(ctx, :mjolnir) do
    ctx
    |> mes(@header)
    |> mes("M-M-Mjolnir!?")
    |> mes("Even though the")
    |> mes("moment is at hand,")
    |> mes("I can scarcely believe...")
    |> next()
    |> mes(@header)
    |> mes("^333333*Sigh...*^000000")
    |> mes(
      "This is almost a disgrace to gods and the Dwarf race. But perhaps, wielding Mjolnir may be your destiny..."
    )
    |> next()
  end

  defp list_materials(ctx, :brisingamen) do
    ctx
    |> mes(@header)
    |> mes("^0000FF4 Freya's Jewel")
    |> mes("4 Silver Ornament")
    |> mes("3 Snow Crystal")
    |> mes("3 Ripple")
    |> mes("3 Drifting Air")
    |> mes("2 Sapphire")
    |> mes("3 Pearl")
    |> mes("10 Opal")
    |> mes("5 Cursed Ruby")
    |> mes("20 Gold")
    |> mes("1 Necklace^000000")
  end

  defp list_materials(ctx, :megingjard) do
    ctx
    |> mes(@header)
    |> mes("^0000FF1 Gleipnir")
    |> mes("20 Gold")
    |> mes("10 Sapphire")
    |> mes("10 Oridecon")
    |> mes("1 Belt^000000...")
  end

  defp list_materials(ctx, :sleipnir) do
    ctx
    |> mes(@header)
    |> mes("^0000FF3 Wheel of the Unknown")
    |> mes("5 Feather of Angel Wing")
    |> mes("3 Sprit of Fish")
    |> mes("4 Amblem of the Sun God")
    |> mes("3 Breath of Spirit")
    |> mes("20 Gold")
    |> mes("10 Elunium")
    |> mes("1 Slotted Boots^000000...")
  end

  defp list_materials(ctx, :mjolnir) do
    ctx
    |> mes(@header)
    |> mes("^0000FF2 Thor's Gauntlets")
    |> mes("4 Iron Maiden")
    |> mes("5 Wrath of Valkyrie")
    |> mes("5 Omen of Tempest")
    |> mes("5 Billow")
    |> mes("20 Oridecon")
    |> mes("5 Elunium")
    |> mes("40 Gold")
    |> mes("1 Stunner^000000...")
  end

  defp start_work(ctx, :brisingamen) do
    ctx
    |> mes(@header)
    |> mes("Never in my wildest")
    |> mes(
      "imaginings have I thought that I'd be crafting this masterpiece for a mere human. Give me a moment."
    )
  end

  defp start_work(ctx, :megingjard) do
    ctx
    |> mes(@header)
    |> mes("Twenty years ago,")
    |> mes("I'd never believe that")
    |> mes(
      "something so powerful and dangerous as Megingjard would end up in the hands of a human..."
    )
  end

  defp start_work(ctx, :sleipnir) do
    ctx
    |> mes(@header)
    |> mes("I never believed")
    |> mes("that the speed of")
    |> mes("Sleipnir would be")
    |> mes("used by a human.")
    |> mes("Give me a moment...")
  end

  defp start_work(ctx, :mjolnir) do
    ctx
    |> mes(@header)
    |> mes("Do not disgrace")
    |> mes("Thor, lord of Thunder,")
    |> mes("or you will regret it.")
    |> mes("Mark my words...")
  end

  defp farewell(ctx, :brisingamen) do
    ctx
    |> mes(@header)
    |> mes(
      "Ah, just look at this dazzling beauty. No other piece of jewelry complemented Freya as well as Brisingamen."
    )
  end

  defp farewell(ctx, :megingjard) do
    ctx
    |> mes(@header)
    |> mes("Here...")
    |> mes("Be careful with how")
    |> mes("you use the strength")
    |> mes("of a god. Just a fair")
    |> mes("warning, human...")
  end

  defp farewell(ctx, :sleipnir) do
    ctx
    |> mes(@header)
    |> mes("There...")
    |> mes("Wear these, and")
    |> mes("move with the speed of")
    |> mes("the legendary Sleipnir...")
  end

  defp farewell(ctx, :mjolnir) do
    ctx
    |> mes(@header)
    |> mes("It's done.")
    |> mes("Take it. How does")
    |> mes("it feel to hold the world's most powerful weapon in your grasp?")
  end
end
