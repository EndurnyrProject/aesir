defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.Piamette do
  @moduledoc """
  Enables Piamette for the current Okolnir instance.

  ## Behavior

  - Enables Piamette when the NPC initializes.

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
        x: 131,
        y: 136,
        dir: 3,
        sprite: 1930,
        name: "Piamette",
        scope: :shared,
        unique_name: "Piamette#aru01"
      },
      %{
        map: "que_qaru02",
        x: 131,
        y: 136,
        dir: 3,
        sprite: 1930,
        name: "Piamette",
        scope: :shared,
        unique_name: "Piamette#aru02"
      },
      %{
        map: "que_qaru03",
        x: 131,
        y: 136,
        dir: 3,
        sprite: 1930,
        name: "Piamette",
        scope: :shared,
        unique_name: "Piamette#aru03"
      },
      %{
        map: "que_qaru04",
        x: 131,
        y: 136,
        dir: 3,
        sprite: 1930,
        name: "Piamette",
        scope: :shared,
        unique_name: "Piamette#aru04"
      },
      %{
        map: "que_qaru05",
        x: 131,
        y: 136,
        dir: 3,
        sprite: 1930,
        name: "Piamette",
        scope: :shared,
        unique_name: "Piamette#aru05"
      },
      %{
        map: "que_qsch01",
        x: 131,
        y: 136,
        dir: 3,
        sprite: 1930,
        name: "Piamette",
        scope: :shared,
        unique_name: "Piamette#sch01"
      },
      %{
        map: "que_qsch02",
        x: 131,
        y: 136,
        dir: 3,
        sprite: 1930,
        name: "Piamette",
        scope: :shared,
        unique_name: "Piamette#sch02"
      },
      %{
        map: "que_qsch03",
        x: 131,
        y: 136,
        dir: 3,
        sprite: 1930,
        name: "Piamette",
        scope: :shared,
        unique_name: "Piamette#sch03"
      },
      %{
        map: "que_qsch04",
        x: 131,
        y: 136,
        dir: 3,
        sprite: 1930,
        name: "Piamette",
        scope: :shared,
        unique_name: "Piamette#sch04"
      },
      %{
        map: "que_qsch05",
        x: 131,
        y: 136,
        dir: 3,
        sprite: 1930,
        name: "Piamette",
        scope: :shared,
        unique_name: "Piamette#sch05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)
    enablenpc(ctx, "Piamette##{get_local(ctx, :"sub$", "")}")
  end
end
