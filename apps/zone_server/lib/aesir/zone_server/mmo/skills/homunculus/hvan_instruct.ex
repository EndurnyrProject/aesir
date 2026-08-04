defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanInstruct do
  @moduledoc "Instruction Change passive skill marker."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8_015,
    name: :hvan_instruct,
    display_name: "Instruction Change",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
