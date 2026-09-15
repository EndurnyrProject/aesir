defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.Mjunia do
  @moduledoc """
  Laments the physical toll and limited prospects of life in Einbech.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbech",
        x: 149,
        y: 154,
        dir: 3,
        sprite: 850,
        name: "Mjunia",
        scope: :shared,
        unique_name: "Mjunia#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Mjunia]")
    |> mes("It's hard being a woman")
    |> mes("in this town. By being born")
    |> mes("here, it's like fate just decided to be especially cruel to me.")
    |> next()
    |> mes("[Mjunia]")
    |> mes("My skin and hands are")
    |> mes("rough from all the work")
    |> mes("I have to do. But worst of")
    |> mes("all... I... I... I've developed")
    |> mes("bigger muscles than most")
    |> mes("guys! Waaaaaah~!")
    |> next()
    |> mes("[Mjunia]")
    |> mes("I wish I could find")
    |> mes("a nice guy from Einbroch")
    |> mes("and get married so I can")
    |> mes("get away from this town.")
    |> mes("But it doesn't look like")
    |> mes("that will happen...")
    |> next()
    |> mes("[Mjunia]")
    |> mes("And I'd never marry")
    |> mes("anyone from Einbech!")
    |> mes("I'd rather die cold and")
    |> mes("alone than cold and married")
    |> mes("to some Einbech hooligan.")
    |> next()
    |> mes("[Mjunia]")
    |> mes("Look at these")
    |> mes("muscles. What do")
    |> mes("you think? Am I pretty?")
    |> mes("^333333*Sniff*^000000 I gave up trying")
    |> mes("to be feminine years ago.")
    |> mes("I have to work so hard...")
    |> close()
  end
end
