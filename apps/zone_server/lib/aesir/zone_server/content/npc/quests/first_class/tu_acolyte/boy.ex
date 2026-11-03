defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.Boy do
  @moduledoc """
  Hidden voice of a crying boy heard near the cemetery during the Acolyte training quest.

  ## Behavior

  - On touch, while the player is on the dog-feeding step, a boy is heard sniffling for his sister.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Capuche
    - Euphy
    - Daegaladh
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_monk",
        x: 243,
        y: 238,
        dir: 5,
        sprite: 139,
        name: "Boy",
        scope: :shared,
        unique_name: "Boy#boy_voi",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :tu_acolyte01, 0) != 10 do
      ctx
    else
      ctx
      |> mes("[??]")
      |> mes("^333333*Sniff*^000000")
      |> mes("Sister...")
      |> close()
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
