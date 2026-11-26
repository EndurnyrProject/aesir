defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MjolnirSeal.Roskva do
  @moduledoc """
  Roskva, Tialfi's sister, explains how to approach the Dwarven Blacksmiths in the Mjolnir Seal
  quest.

  ## Behavior

  - On the quest, she warns that the Dwarves must be spoken to courteously and gives the order
    to visit them: clockwise from the East, or counterclockwise from the North, depending on
    the route Tialfi assigned.
  - Otherwise she reminisces about the people who once lived nearby.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - Samuray22
    - L0ne_W0lf
    - Zephyrus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "prt_fild01", x: 196, y: 47, dir: 3, sprite: 703, name: "Roskva", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :god_mjo_0, 0) do
      1 -> advise(ctx, "East", "clock wise", "North")
      2 -> advise(ctx, "North", "counter clock wise", "East")
      _ -> reminisce(ctx)
    end
  end

  defp advise(ctx, first, direction, last) do
    ctx
    |> mes("[Roskva]")
    |> mes(
      "You should know that Dwarven Blacksmiths are extremely offended if you do not speak to them with the utmost respect."
    )
    |> next()
    |> mes("[Roskva]")
    |> mes("So it's really")
    |> mes("important that you")
    |> mes("speak to the Dwarves")
    |> mes("as courteously as you can.")
    |> mes("The first Dwarf you must visit")
    |> mes("can be found to the #{first}.")
    |> next()
    |> mes("[Roskva]")
    |> mes(
      "Travel in a #{direction} direction around Midgard and seek out the other Dwarves in order. Your final destination will be to the #{last}."
    )
    |> next()
    |> mes("[Roskva]")
    |> mes(
      "If you happen to speak to them in the wrong order, please go talk to my brother Tialfi again."
    )
    |> close()
  end

  defp reminisce(ctx) do
    ctx
    |> mes("[Roskva]")
    |> mes(
      "A long time ago, many people used to frequent this area. Friends and families would live here, sharing happiness and sadness."
    )
    |> next()
    |> mes("[Roskva]")
    |> mes(
      "But they're all gone now. My parents and my friends have all gone to a place whose name I don't even know."
    )
    |> next()
    |> mes("[Roskva]")
    |> mes("I can't help")
    |> mes("but feel lonesome...")
    |> close()
  end
end
