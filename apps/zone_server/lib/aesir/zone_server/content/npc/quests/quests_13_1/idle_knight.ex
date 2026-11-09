defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.IdleKnight do
  @moduledoc """
  Litheron, a Knight taking a break from the Morocc restoration work in the job quest
  hideout.

  ## Behavior

  - Greets the player and, when the visitor is a Knight, adds the pot-calling-the-kettle remark.
  - Explains that he came to drink away from the restoration work.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_job01",
        x: 81,
        y: 79,
        dir: 5,
        sprite: 733,
        name: "Idle Knight",
        scope: :shared,
        unique_name: "Idle Knight#dan_08"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Litheron]")
      |> mes("What, haven't you seen a Knight before?")
      |> mes("You think Knights don't belong here?")

    ctx =
      if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:knight) do
        mes(ctx, "Looks like this is a case of the pot calling the kettle black.")
      else
        ctx
      end

    ctx
    |> next()
    |> mes("[Litheron]")
    |> mes("You know, I'm just here to take a break from the town restoration work.")
    |> mes("There aren't many places that you can have a drink without being caught. You know?")
    |> close()
  end
end
