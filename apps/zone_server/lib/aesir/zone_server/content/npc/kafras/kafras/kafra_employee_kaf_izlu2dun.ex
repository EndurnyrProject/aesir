defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraEmployeeKafIzlu2dun do
  @moduledoc """
  Kafra employee at Byalan Island who runs the Kafra services, after handing Novices on the
  merchant job change quest to the pre-renewal merchant Kafra.

  ## Behavior

  - Hands the conversation to the merchant job change Kafra when a pre-renewal Novice is on that
    quest, then resumes with the branch welcome.
  - Greets the player with the branch cutin and the branch welcome, then opens the shared Kafra
    menu with this branch's fees and available services.
  - On the save option, stores the respawn point for this location and closes with the branch
    farewell.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - L0ne_W0lf
    - kobra_k88
    - Samuray22
    - Evera
    - Lupus
    - Euphy
    - Lemongrass

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/kafras.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlu2dun",
        x: 106,
        y: 58,
        dir: 8,
        sprite: 116,
        name: "Kafra Employee::kaf_izlu2dun",
        scope: :shared,
        unique_name: "kaf_izlu2dun"
      }
    ]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafend
  alias Aesir.ZoneServer.Content.Npc.Functions.FKafra
  alias Aesir.ZoneServer.Content.Npc.PreRe.Functions.FMerckafra
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: no_return()
  def on_talk(ctx) do
    ctx = ctx |> cutin("kafra_03", 2) |> maybe_merchant_quest()

    {ctx, _} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome to the")
      |> mes("Kafra Corporation.")
      |> mes("Kafra's Employees are")
      |> mes("always ready to serve you.")
      |> mes("How can I help you today?")
      |> FKafra.call([5, 2, 1, 120, 1200])

    ctx
    |> savepoint("izlu2dun", 87, 170)
    |> FKafend.call([0, 1, "at Byalan Island"])
  end

  # Only the pre-renewal merchant job change has the delivery Kafra this branch forwards to.
  defp maybe_merchant_quest(ctx) do
    if not Rathena.truthy?(checkre(ctx, 0)) and base_job(ctx) == :novice and
         get_char_var(ctx, :job_merchant_q2, 0) > 0 do
      {ctx, _} =
        case GameMode.mode() do
          :renewal ->
            raise "NPC helper F_MercKafra called from kafras/kafras.txt (Kafra Employee::kaf_izlu2dun) has no renewal target"

          :pre_renewal ->
            FMerckafra.call(ctx, [])
        end

      ctx
    else
      ctx
    end
  end
end
