defmodule Aesir.ZoneServer.Content.Npc.Jobs.Valkyrie.HeartOfYmir do
  @moduledoc """
  Sends rebirth candidates who have read the Book of Ymir to Valhalla.

  ## Behavior

  - Warps second-class characters of base level 99 and job level 50 or higher who have
    read the Book of Ymir to Valhalla; does nothing for anyone else.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Nana
    - Poki
    - Lupus
    - L0ne_W0lf
    - Mass Zero
    - Silentdragon
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in05",
        x: 49,
        y: 43,
        dir: 1,
        sprite: 111,
        name: "Heart of Ymir",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if base_level(ctx) > 98 and job_level(ctx) > 49 and
         Rathena.job_id(class(ctx)) >= Rathena.job_id(:knight) and
         Rathena.job_id(class(ctx)) <= Rathena.job_id(:crusader2) and
         get_char_var(ctx, :valkyrie_Q, 0) == 2 do
      warp(ctx, "valkyrie", 48, 8)
    else
      ctx
    end
  end
end
