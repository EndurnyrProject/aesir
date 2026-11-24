defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.UnethicalMachine do
  @moduledoc """
  Lets the player destroy the machine during the rebellion quest.

  ## Behavior

  - Consumes a Marine Sphere Bottle and triggers the explosion.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
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
        map: "lhz_dun02",
        x: 244,
        y: 226,
        dir: 0,
        sprite: 111,
        name: "Unethical Machine",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_tre, 0) == 54 do
      if Rathena.truthy?(count_item(ctx, 7138)) do
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("This must be it...whoa, it looks very spooky.")
        |> mes("Today, I am going to destroy you")
        |> mes("for making innocent people's lives miserable!")
        |> next()
        |> mes("- You threw a Marine Sphere Bottle toward the machine. -")
        |> next()
        |> mes("BOOM!")
        |> specialeffect2(:sui_explosion)
        |> enablenpc("HiddenExplosion")
        |> mapannounce("lhz_dun02", "Beep------------------ ", 1, 10_079_487)
        |> delitem(7138, 1)
        |> set_char_var(:hg_tre, 55)
        |> close()
      else
        ctx
        |> mes("- You were staggered for the fact that")
        |> mes("you forgot to bring the Marine Sphere Bottle with you. -")
        |> close()
      end
    else
      ctx
    end
  end
end
