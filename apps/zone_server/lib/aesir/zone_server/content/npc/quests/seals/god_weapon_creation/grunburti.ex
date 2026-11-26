defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.GodWeaponCreation.Grunburti do
  @moduledoc """
  The dwarf Grunburti waits in the guild dungeons and leads guild masters to his underground
  laboratory to forge the godly items once all four seals are broken.

  ## Behavior

  - Talks about the Dwarves and about how he ended up stranded in Midgard.
  - While a seal still holds, he only previews the materials of each godly item to a guild
    master once every seal has reached its first stage; anyone else is turned away.
  - Once every seal is released, he refuses players who are not guild masters.
  - A guild master carrying the full materials of any godly item is warped to the laboratory;
    one without them is reminded of the materials of the item they pick.

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
        map: "gld_dun01",
        x: 28,
        y: 85,
        dir: 0,
        sprite: 826,
        name: "Grunburti",
        scope: :shared,
        unique_name: "GodDwarf",
        hidden_name: "1"
      },
      %{
        map: "gld_dun02",
        x: 85,
        y: 84,
        dir: 0,
        sprite: 826,
        name: "Grunburti",
        scope: :shared,
        unique_name: "Grunburti#2"
      },
      %{
        map: "gld_dun03",
        x: 92,
        y: 105,
        dir: 0,
        sprite: 826,
        name: "Grunburti",
        scope: :shared,
        unique_name: "Grunburti#3"
      },
      %{
        map: "gld_dun04",
        x: 268,
        y: 230,
        dir: 0,
        sprite: 826,
        name: "Grunburti",
        scope: :shared,
        unique_name: "Grunburti#4"
      }
    ]

  @header "[Dwarf Grunburti]"

  @items ["Brisingamen", "Megingjard", "Sleipnir", "Mjolnir"]

  @requirements [
    {"Brisingamen",
     [
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
     ]},
    {"Megingjard", [{7058, 1}, {969, 20}, {726, 10}, {984, 10}, {2627, 1}]},
    {"Sleipnir",
     [
       {7076, 3},
       {7079, 5},
       {7083, 3},
       {7086, 4},
       {7087, 3},
       {969, 20},
       {985, 10},
       {2406, 1}
     ]},
    {"Mjolnir",
     [
       {7074, 2},
       {7075, 4},
       {7078, 5},
       {7089, 5},
       {7091, 5},
       {984, 20},
       {985, 5},
       {969, 40},
       {1522, 1}
     ]}
  ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@header)
      |> mes("A human?!")
      |> mes("This land is full")
      |> mes("of your kind. What")
      |> mes("brings you here?")
      |> next()
      |> mes(@header)
      |> mes("Living in Midgard and away from")
      |> mes("my home town is painful enough, let alone facing a whiny human. Leave me alone!")
      |> next()
      |> select([
        "Ask him about Dwarves.",
        "Ask him what he is doing.",
        "Request weapon creation.",
        "Cancel."
      ])

    case choice do
      1 -> about_dwarves(ctx)
      2 -> about_himself(ctx)
      3 -> request_weapon(ctx)
      4 -> dismiss(ctx)
      _ -> ctx
    end
  end

  defp about_dwarves(ctx) do
    ctx
    |> mes(@header)
    |> mes("What's to know about Dwarves?")
    |> mes("We're the toughest race. After all, we can live anywhere, no matter")
    |> mes("how harsh the environment may be.")
    |> next()
    |> mes(@header)
    |> mes("I doubt your feeble mind can comprehend the how unendurable")
    |> mes("it must be for you to live in my homeland, but you can try.")
    |> mes("Try to imagine.")
    |> next()
    |> mes(@header)
    |> mes(
      "Most of the knowledge and skills that you humans are so proud of were probably handed down from Dwarves."
    )
    |> next()
    |> mes(@header)
    |> mes("This is especially true in the")
    |> mes(
      "case of smithing. Even the tools and weapons of the gods were made by my ancestors. You know that?"
    )
    |> next()
    |> mes(@header)
    |> mes(
      "We have the greatest knowlege and skills, but have accepted our fate to live in the cold, barren lands of the Giants."
    )
    |> close()
  end

  defp about_himself(ctx) do
    ctx
    |> mes(@header)
    |> mes(
      "Did you just ask what I am doing here? Mwahahaha! Waiting for any humans stupid enough to come"
    )
    |> mes("here so I can kick their ass!")
    |> next()
    |> mes(@header)
    |> mes(
      "Oh don't worry. I'd only humiliate myself by fighting with a weakling like you. Humans are so fragile, but they stubbornly cling to their arrogance and fight amongst"
    )
    |> mes("each other.")
    |> next()
    |> mes(@header)
    |> mes(
      "As a race, your people are just hopeless. I wouldn't even share the same continent with a human! But alas, I have no choice."
    )
    |> next()
    |> mes(@header)
    |> mes("The path to my hometown")
    |> mes(
      "disappeared after the war 1,000 years ago. Somehow, I can no longer find the way through the Yggdrasil Tree that will take me back..."
    )
    |> next()
    |> mes(@header)
    |> mes("I'm stuck here in Midgard.")
    |> mes(
      "At least I was fortunate enough to find this cave. We Dwarves are most cozy living underground, after all."
    )
    |> close()
  end

  defp dismiss(ctx) do
    ctx
    |> mes(@header)
    |> mes("Muhahahahahaha!")
    |> mes("Out of my sight,")
    |> mes("you dirty, filthy")
    |> mes("human...!")
    |> close()
  end

  defp request_weapon(ctx) do
    ctx = set_local(ctx, :GID, getcharid(ctx, 2))

    cond do
      seal_holds?(ctx) -> sealed_request(ctx)
      is_guild_leader(ctx) == 0 -> not_a_guild_master(ctx)
      true -> inspect_materials(ctx)
    end
  end

  defp seal_holds?(ctx) do
    Enum.any?(["God1", "God2", "God3", "God4"], fn seal ->
      get_server_var(ctx, seal, 0) < get_server_temp_var(ctx, "god_check2", 0)
    end)
  end

  defp seals_weakened?(ctx) do
    Enum.all?(["God1", "God2", "God3", "God4"], fn seal ->
      get_server_var(ctx, seal, 0) >= get_server_temp_var(ctx, "god_check1", 0)
    end)
  end

  defp sealed_request(ctx) do
    if seals_weakened?(ctx) and is_guild_leader(ctx) == 1 do
      preview_materials(ctx)
    else
      ctx
      |> mes(@header)
      |> mes(
        "We Dwarves have too much pride to demonstrate our skills in front of a lowly human!"
      )
      |> next()
      |> mes(@header)
      |> mes(
        "Stop bothering me and get out of here! Go play with some monsters, you simple minded fool!"
      )
      |> close()
    end
  end

  defp preview_materials(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@header)
      |> mes("Hmm...")
      |> mes(
        "I'll need some things to make a weapon for you. What exactly were you interested in having?"
      )
      |> next()
      |> select(@items)

    case choice do
      choice when choice in 1..4 ->
        ctx
        |> list_materials(choice)
        |> mes(@header)
        |> mes(not_yet(choice))
        |> close()

      _ ->
        ctx
    end
  end

  defp not_yet(1) do
    "However, the time for me to create this Brisingamen has not yet come. You'll have to wait until the seals are released. Mwahahaha!"
  end

  defp not_yet(2) do
    "However, the seals on Megingjard have not yet been released. Until then, you'll have to wait! Bwahahaha!"
  end

  defp not_yet(3) do
    "But even so, I can't create Sleipnir until the seals have been broken. Otherwise, you're out of luck, human. Hahaha~!"
  end

  defp not_yet(4) do
    "But I can't even create a replica of Mjolnir if the seals are still in place. Until they're released, you'll just have to wait. Bwahaha!"
  end

  defp not_a_guild_master(ctx) do
    ctx
    |> mes(@header)
    |> mes("I'll only present")
    |> mes("my magnificent skills")
    |> mes("to a human of incredibly")
    |> mes("high standing!")
    |> next()
    |> mes(@header)
    |> mes("Although I hate")
    |> mes("most humans, I have")
    |> mes(
      "no choice but to respect the ones chosen by destiny. Go and bring your ^0000FFguildmaster^000000!"
    )
    |> close()
  end

  defp inspect_materials(ctx) do
    ctx =
      ctx
      |> mes(@header)
      |> mes("Although it is very humiliating to present my valuable skills to a human being...")
      |> next()
      |> mes(@header)
      |> mes(
        "All the seals have been released, and he who holds the Emperium is chosen by destiny. I have no choice but to respect you."
      )
      |> next()
      |> mes(@header)
      |> mes(
        "First of all, I shall confirm whether or not you have brought all the necessary materials to forge a godly item! I hate it when humans come here without any purpose!"
      )
      |> next()

    case Enum.find(@requirements, fn {_item, materials} -> has_all?(ctx, materials) end) do
      {item, _materials} ->
        ctx
        |> mes(@header)
        |> mes("Hmm...")
        |> mes("I guess you")
        |> mes("want to have")
        |> mes("^0000FF#{item}^000000!")
        |> next()
        |> invite_to_laboratory()

      nil ->
        unprepared(ctx)
    end
  end

  defp has_all?(ctx, materials) do
    Enum.all?(materials, fn {item_id, amount} -> count_item(ctx, item_id) >= amount end)
  end

  defp invite_to_laboratory(ctx) do
    ctx
    |> mes(@header)
    |> mes("Hmpf.")
    |> mes(
      "I can't get any work done in here. Come with me to the ^0000FFunderground laboratory^000000 as my guest, human."
    )
    |> next()
    |> mes(@header)
    |> mes(
      "Now hurry up! ^0000FFOnly one of each godly item^000000 will be given to the humans ^FF0000right after all the seals are released^000000!"
    )
    |> close2()
    |> warp("que_god01", 214, 63)
  end

  defp unprepared(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@header)
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes(@header)
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes(@header)
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> mes(".............")
      |> next()
      |> mes(@header)
      |> mes(
        "How dare you come here unprepared?! Did you forget what you needed to bring? Listen carefully this time!"
      )
      |> next()
      |> select(@items)

    case choice do
      choice when choice in 1..4 ->
        ctx
        |> remind_materials(choice)
        |> mes(@header)
        |> mes("Hmmm, but now")
        |> mes("that the seals have")
        |> mes("been released, you must hurry before another human can claim")
        |> mes("one of the godly items...")
        |> next()
        |> mes(@header)
        |> mes("Hurry...!")
        |> mes("Once I forge")
        |> mes(forged_name(choice))
        |> mes("the seals will")
        |> mes("activate again!")
        |> close()

      _ ->
        ctx
    end
  end

  defp forged_name(4), do: "the Mjolnir,"
  defp forged_name(choice), do: "#{Enum.at(@items, choice - 1)},"

  defp remind_materials(ctx, 4) do
    ctx
    |> mes(@header)
    |> mes("I will need...")
    |> mes("^0000FF2 Thor's Gauntlets")
    |> mes("4 Iron Maiden")
    |> mes("5 Wrath of Valkyrie")
    |> mes("5 Omen of Tempest")
    |> mes("5 Billow")
    |> mes("20 Oridecon")
    |> mes("5 Elunium")
    |> mes("40 Gold")
    |> next()
  end

  defp remind_materials(ctx, choice), do: list_materials(ctx, choice)

  defp list_materials(ctx, 1) do
    ctx
    |> mes(@header)
    |> mes("I will need...")
    |> mes("^0000FF4 Freya's Jewel")
    |> mes("4 Silver Ornament")
    |> mes("3 Snow Crystal")
    |> mes("3 Ripple")
    |> mes("3 Drifting Air")
    |> mes("2 Sapphire")
    |> mes("3 Pearl")
    |> mes("10 Opal")
    |> mes("5 Cursed Ruby")
    |> mes("20 Gold^000000")
    |> mes("1 Necklace^000000...")
    |> next()
  end

  defp list_materials(ctx, 2) do
    ctx
    |> mes(@header)
    |> mes("I will need...")
    |> mes("^0000FF1 Gleipnir")
    |> mes("20 Gold")
    |> mes("10 Sapphire")
    |> mes("10 Oridecon")
    |> mes("1 Belt^000000")
    |> next()
  end

  defp list_materials(ctx, 3) do
    ctx
    |> mes(@header)
    |> mes("I will need...")
    |> mes("^0000FF3 Wheel of the Unknown")
    |> mes("5 Feather of Angel Wing")
    |> mes("3 Sprit of Fish")
    |> mes("4 Amblem of the Sun God")
    |> mes("3 Breath of Spirit")
    |> mes("20 Gold")
    |> mes("10 Elunium")
    |> mes("1 Slotted Boots^000000")
    |> next()
  end

  defp list_materials(ctx, 4) do
    ctx
    |> mes(@header)
    |> mes("I will need...")
    |> mes("^0000FF2 Thor's Gauntlets")
    |> mes("4 Iron Maiden")
    |> mes("5 Wrath of Valkyrie")
    |> mes("5 Omen of Tempest")
    |> mes("5 Billow")
    |> mes("20 Oridecon")
    |> mes("5 Elunium")
    |> mes("40 Gold")
    |> mes("1 Stunner^000000")
    |> next()
  end
end
