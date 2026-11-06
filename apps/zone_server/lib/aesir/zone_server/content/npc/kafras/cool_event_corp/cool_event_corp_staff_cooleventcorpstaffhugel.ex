defmodule Aesir.ZoneServer.Content.Npc.Kafras.CoolEventCorp.CoolEventCorpStaffCooleventcorpstaffhugel do
  @moduledoc """
  Cool Event Corp. staff member in Hugel who runs the company's counter.

  ## Behavior

  - Greets the player with the Cool Event Corp. cutin and opens the branch menu: save, storage,
    pushcart rental, the storage password service and, where offered, a teleport.
  - Saves the respawn point for this branch.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/cool_event_corp.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hugel",
        x: 88,
        y: 168,
        dir: 4,
        sprite: 874,
        name: "Cool Event Corp. Staff::CoolEventCorpStaffHugel",
        scope: :shared,
        unique_name: "CoolEventCorpStaffHugel"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FCooleventcorp
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: no_return()
  def on_talk(ctx) do
    FCooleventcorp.call(ctx, [
      "Save:Use Storage::Rent a Pushcart:Storage Password Service:Cancel",
      "in the village of Hugel",
      "hugel",
      96,
      155
    ])
  end
end
