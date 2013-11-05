classdef WorldFixedBodyPoseConstraint < MultipleTimeKinematicConstraint
  % Constrain the posture (position and orientation) of a body to be fixed
  % within a time interval
  % @param robot         -- A RigidBodyManipulator or a
  %                         TimeSteppingRigidBodyManipulator
  % @param body          -- An int scalar, the body index
  % @param tspan         -- Optional input, a 1x2 double array, the time span
  %                             of this constaint being active. Default is
  %                             [-inf inf]
  
  properties(SetAccess = protected)
    body 
    body_name
  end
  
  methods
    function obj = WorldFixedBodyPoseConstraint(robot,body,tspan)
      if(nargin == 2)
        tspan = [-inf inf];
      end
      ptr = constructPtrWorldFixedBodyPoseConstraintmex(robot.getMexModelPtr,body,tspan);
      obj = obj@MultipleTimeKinematicConstraint(robot,tspan);
      sizecheck(body,[1,1]);
      if(~isnumeric(body))
        error('Drake:WorldFixedBodyPoseConstraint: body must be an integer');
      end
      obj.body = floor(body);
      obj.body_name = obj.robot.getBody(obj.body).linkname;
      obj.mex_ptr = ptr;
    end
    
    function num = getNumConstraint(obj,t)
      valid_t = t(obj.isTimeValid(t));
      if(length(valid_t)>=2)
        num = 2;
      else
        num = 0;
      end
    end
    
    function [c,dc_valid] = eval_valid(obj,valid_t,valid_q)
      num_valid_t = size(valid_t,2);
      nq = obj.robot.getNumDOF();
      sizecheck(valid_q,[nq,num_valid_t]);
      pos = zeros(3,num_valid_t);
      quat = zeros(4,num_valid_t);
      if(nargout == 2)
        dpos = zeros(3*num_valid_t,nq);
        dquat = zeros(4*num_valid_t,nq);
      end
      for i = 1:num_valid_t
        kinsol = doKinematics(obj.robot,valid_q(:,i),false,false);
        if(nargout == 1)
          pos_tmp = forwardKin(obj.robot,kinsol,obj.body,[0;0;0],2);
        elseif(nargout == 2)
          [pos_tmp,J_tmp] = forwardKin(obj.robot,kinsol,obj.body,[0;0;0],2);
          dpos(3*(i-1)+(1:3),:) = J_tmp(1:3,:);
          dquat(4*(i-1)+(1:4),:) = J_tmp(4:7,:);
        end
        pos(:,i) = pos_tmp(1:3);
        quat(:,i) = pos_tmp(4:7);
      end
      diff_pos = diff(pos,[],2);
      diff_pos = [diff_pos pos(:,1)-pos(:,num_valid_t)];
      quat2 = [quat(:,2:end) quat(:,1)];
      c1 = sum(diff_pos.*diff_pos,2);
      c2 = sum(quat.*quat2,1);
      c = [sum(c1,1);sum(c2.^2)];
      if(nargout == 2)
        dc1 = reshape(permute(reshape((bsxfun(@times,reshape((4*pos-2*[pos(:,2:end) pos(:,1)]-2*[pos(:,end) pos(:,1:end-1)]),[],1),ones(1,nq))...
          .*dpos)',nq,3,num_valid_t),[2,1,3]),3,nq*num_valid_t);
        dcdquat = (bsxfun(@times,ones(4,1),2*c2).*quat2+bsxfun(@times,ones(4,1),2*[c2(end) c2(1:end-1)]).*[quat(:,end) quat(:,1:end-1)]);
        dc_valid = reshape([sum(dc1,1);sum(reshape(permute(reshape((bsxfun(@times,ones(1,nq),reshape(dcdquat,[],1)).*dquat)',nq,4,num_valid_t),[2,1,3]),4,nq*num_valid_t),1)],2,nq*num_valid_t);
      end
    end
    
    function [lb,ub] = bounds(obj,t)
      valid_t = t(obj.isTimeValid(t));
      if(length(valid_t)>=2)
        n_breaks = length(valid_t);
        lb = [0;n_breaks];
        ub = [0;n_breaks];
      else
        lb = [];
        ub = [];
      end
    end
    
    function name_str = name(obj,t)
      valid_t = t(obj.isTimeValid(t));
      if(length(valid_t)>=2)
        name_str = {sprintf('World fixed body pose constraint for %s position',obj.body_name);...
          sprintf('World fixed body pose constraint for %s orientation',obj.body_name)};
      else
        name_str = {};
      end
    end
    
    function obj = updateRobot(obj,robot)
      obj.robot = robot;
      updatePtrWorldFixedBodyPoseConstraintmex(obj.mex_ptr,'robot',robot.getMexModelPtr);
    end
    
    function ptr = constructPtr(varargin)
      ptr = constructPtrWorldFixedBodyPoseConstraintmex(varargin{:});
    end
  end
end