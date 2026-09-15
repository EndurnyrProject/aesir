defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.UtanKid149165 do
  @moduledoc """
  Shares Klumatan's fear of the Utan adulthood bungee jump.

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
        x: 149,
        y: 165,
        dir: 4,
        sprite: 781,
        name: "Utan Kid",
        scope: :shared,
        unique_name: "Utan Kid#3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      ctx
      |> mes("[Klumatan]")
      |> mes("It's really scary, falling from")
      |> mes("such a high place...")
      |> mes("But I guess you have to do it,")
      |> mes("otherwise no one will ever")
      |> mes("consider you a grownup.")
      |> next()
      |> mes("[Klumatan]")
      |> mes("I guess I don't want to")
      |> mes("be a grownup right away.")
      |> mes("But some kids my age are")
      |> mes("in too big of a hurry")
      |> mes("to not be kids anymore.")
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
