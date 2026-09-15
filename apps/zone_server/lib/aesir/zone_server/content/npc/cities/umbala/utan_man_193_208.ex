defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.UtanMan193208 do
  @moduledoc """
  Recounts Weitan's own adulthood bungee jump.

  ## Behavior

  - Speaks intelligibly only after Umbalan language progress reaches stage 3.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "umbala",
        x: 193,
        y: 208,
        dir: 6,
        sprite: 789,
        name: "Utan Man",
        scope: :shared,
        unique_name: "Utan Man#3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      ctx
      |> mes("[Weitan]")
      |> mes("I too did the bungee jump when I")
      |> mes("was young. I remember it well...")
      |> mes("It was my first time, and the")
      |> mes("ground rushed up to meet me...")
      |> mes("For a moment, I thought I was")
      |> mes("going to get myself killed...")
      |> next()
      |> mes("[Weitan]")
      |> mes("But after I made it, I was so")
      |> mes("proud of myself~")
      |> mes("Some Utans may not agree, but")
      |> mes("I think bungee jumping is an")
      |> mes("important part of the ceremony")
      |> mes("of adulthood.")
      |> close()
    else
      ctx
      |> mes("[???]")
      |> mes("Umbahumba umumbah.")
      |> mes("Umbahumbah umbabah.")
      |> mes("Umbahumhumbabahum.")
      |> close()
    end
  end
end
